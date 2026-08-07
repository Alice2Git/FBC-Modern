/* temp result ustring allocation
**
** Port of str_tempres.c.
**
** A FUNCTION returning a ustring really returns a POINTER to a descriptor
** (symbProcRecalcRealType() rewrites the result type). The callee's own result
** variable lives on its stack frame, which is dead the moment it returns -- so
** the descriptor's guts are MOVED into a pooled temp descriptor and a pointer
** to that is returned instead.
**
** Setting FB_TEMPSTRBIT is what makes the caller's assignment steal the buffer
** rather than copy it, and what makes fb_hUStrDelTemp() free the data when the
** result is discarded.
*/

#include "fb.h"

FBCALL FBUSTRING *fb_UStrAllocTempResult( FBUSTRING *src )
{
	FBUSTRING *dsc;

	FB_STRLOCK();

	/* alloc a temporary descriptor (the current one on the stack will be trashed) */
	dsc = fb_hUStrAllocTempDesc( );
	if( dsc == NULL )
	{
		FB_STRUNLOCK();
		return &__fb_ctx.unull_desc;
	}

	/* copy just the descriptor, marking it a temp */
	dsc->data = src->data;
	dsc->len  = src->len | FB_TEMPSTRBIT;
	dsc->size = src->size;

	/* ownership has moved; leave nothing behind that could be freed twice */
	src->data = NULL;
	src->len  = 0;
	src->size = 0;

	FB_STRUNLOCK();

	return dsc;
}
