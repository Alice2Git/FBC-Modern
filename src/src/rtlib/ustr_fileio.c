/* LINE INPUT # and INPUT # for ustrings, honouring OPEN ... ENCODING
**
** THE BUG THIS FIXES WAS DOUBLE ENCODING, NOT A MISSING FEATURE
**
** A ustring is UTF-8 on disk by construction, so LINE INPUT # and INPUT #
** originally read into a temp STRING and decoded the bytes. That is right for a
** plain file and WRONG for one opened with ENCODING, because the file device
** has already decoded for you. Reading "h<U+00E9>i" from a utf16 file gave:
**
**   the device decodes UTF-16 -> one narrow byte 0xE9
**   STRING -> USTRING then reads 0xE9 as UTF-8, which is malformed
**   result: h, U+FFFD, i -- the character is gone
**
** and writing was the mirror image, producing 'h', 'A-tilde', 'copyright', 'i'
** in the file: the UTF-8 bytes re-encoded as if each byte were a character.
**
** ENCODING IS A RUNTIME PROPERTY, so this cannot be settled in the compiler the
** way the STRING/WSTRING split is. Hence these entry points, which branch on
** handle->encod:
**
**   FB_FILE_ENCOD_ASCII   the file is plain bytes. Use the narrow path and
**                         decode UTF-8 -- a ustring file is UTF-8, unchanged.
**   anything else         the device decodes for us. Use the WIDE path and take
**                         its FB_WCHARs, which is what WSTRING already does
**                         correctly.
*/

#include "fb.h"

/* TRUE when the file device does the decoding, so we must not decode again. */
static int hIsEncoded( FB_FILE *handle )
{
	return (handle != NULL) && (handle->encod != FB_FILE_ENCOD_ASCII);
}

/* ------------------------------------------------------------- LINE INPUT #
**
** The encoded branch reads one FB_WCHAR at a time and grows its own buffer,
** rather than calling fb_FileLineInputWstr, which needs a caller-supplied
** maximum and truncates past it. A ustring is var-len, so imposing a line
** length here would be a limit the plain-file path does not have -- and one
** that would truncate silently. The CR/LF handling mirrors
** dev_file_encod_readline_wstr.c.
*/

#define LINEBUF_INIT 256

FBCALL int fb_FileLineInputUStr( int fnum, FBUSTRING *dst )
{
	FB_FILE *handle = FB_FILE_TO_HANDLE( fnum );
	int res;

	if( !FB_HANDLE_USED( handle ) )
		return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );

	if( !hIsEncoded( handle ) )
	{
		/* plain file: bytes, and a ustring file is UTF-8 */
		FBSTRING tmp = { 0, 0, 0 };

		res = fb_FileLineInput( fnum, &tmp, FB_STRSIZEVARLEN, 0 );
		fb_UStrAssignFromA( dst, FB_USTRSIZEVARLEN, &tmp, FB_STRSIZEVARLEN,
		                    0, 0 );
		fb_StrDelete( &tmp );

		return res;
	}

	{
		FB_WCHAR *buf;
		ssize_t cap = LINEBUF_INIT, n = 0;

		buf = (FB_WCHAR *)malloc( (cap + 1) * sizeof( FB_WCHAR ) );
		if( buf == NULL )
			return fb_ErrorSetNum( FB_RTERROR_OUTOFMEM );

		res = FB_RTERROR_OK;

		for( ;; )
		{
			FB_WCHAR c;
			size_t len;

			res = fb_FileGetDataEx( handle, 0, &c, 1, &len, FALSE, TRUE );
			if( (res != FB_RTERROR_OK) || (len == 0) )
				break;

			if( c == _LC('\r') )
			{
				/* swallow a following LF, but only if it is there */
				res = fb_FileGetDataEx( handle, 0, &c, 1, &len, FALSE, TRUE );
				if( (res == FB_RTERROR_OK) && (len != 0) && (c != _LC('\n')) )
					fb_FilePutBackEx( handle, &c, 1 );
				break;
			}

			if( c == _LC('\n') )
				break;

			if( n >= cap )
			{
				FB_WCHAR *bigger;

				cap *= 2;
				bigger = (FB_WCHAR *)realloc( buf, (cap + 1) * sizeof( FB_WCHAR ) );
				if( bigger == NULL )
				{
					free( buf );
					return fb_ErrorSetNum( FB_RTERROR_OUTOFMEM );
				}
				buf = bigger;
			}

			buf[n++] = c;
		}

		buf[n] = _LC('\0');

		/* Re-encodes only where FB_WCHAR is not 16 bits; a straight copy on
		   Windows, since a ustring already is UTF-16. */
		fb_UStrAssignFromW( dst, FB_USTRSIZEVARLEN, buf, 0, 0 );

		free( buf );

		return fb_ErrorSetNum( res );
	}
}

/* ------------------------------------------------------------------ INPUT #
**
** The token splitting, quoting and comma rules live in the existing narrow and
** wide tokenisers, so this only picks which one runs. Both bound a token at
** FB_INPUT_MAXSTRINGLEN, so a ustring is neither more nor less capable than a
** wstring here.
**
** The file comes from the INPUT context, which fb_FileInput() set: INPUT # is
** two calls, one naming the file and one per destination.
*/

FBCALL int fb_InputUStr( FBUSTRING *dst )
{
	FB_INPUTCTX *ctx = FB_TLSGETCTX( INPUT );

	if( hIsEncoded( ctx->handle ) )
	{
		FB_WCHAR buffer[FB_INPUT_MAXSTRINGLEN+1];

		fb_FileInputNextTokenWstr( buffer, FB_INPUT_MAXSTRINGLEN, TRUE );
		fb_UStrAssignFromW( dst, FB_USTRSIZEVARLEN, buffer, 0, 0 );
	}
	else
	{
		FBSTRING tmp = { 0, 0, 0 };

		fb_InputString( &tmp, FB_STRSIZEVARLEN, 0 );
		fb_UStrAssignFromA( dst, FB_USTRSIZEVARLEN, &tmp, FB_STRSIZEVARLEN,
		                    0, 0 );
		fb_StrDelete( &tmp );
	}

	return fb_ErrorSetNum( FB_RTERROR_OK );
}
