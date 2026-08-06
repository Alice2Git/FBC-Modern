/* scope-exit and ERASE destruction for arrays of var-len ustrings
**
** Port of array_destructstr.c / array_erasestr.c. Without these an array of
** ustrings leaks every element: the array itself is freed, but the descriptors
** inside it still own their buffers.
*/

#include "fb.h"

void fb_hArrayDtorUStr( FBARRAY *array, FB_DEFCTOR dtor, size_t keep_idx )
{
	size_t elements;
	FBUSTRING *this_;

	(void)dtor;

	if( array->ptr == NULL )
		return;

	elements = fb_ArrayLen( array );

	/* dtors run in reverse order, as everywhere else in FB */
	this_ = (FBUSTRING *)array->ptr + (elements-1);

	while( elements > keep_idx ) {
		if( this_->data != NULL )
			fb_UStrDelete( this_ );
		--this_;
		--elements;
	}
}

FBCALL void fb_ArrayDestructUStr( FBARRAY *array )
{
	fb_hArrayDtorUStr( array, NULL, 0 );
}

FBCALL void fb_ArrayUStrErase( FBARRAY *array )
{
	fb_ArrayDestructUStr( array );

	/* only free the memory if it's not a fixed length array */
	if( array && !(array->flags & FBARRAY_FLAGS_FIXED_LEN) ) {
		fb_ArrayErase( array );
	}
}
