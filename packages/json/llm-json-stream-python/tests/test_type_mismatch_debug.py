"""Type mismatch debug tests."""

import pytest
from tests.utils.stream_utils import stream_text_in_chunks


class TestTypeMismatchDebug:
    """Type mismatch debugging test suite."""

    @pytest.mark.asyncio
    async def test_debug_string_as_number_mismatch(self):
        """Debug string accessed as number."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_debug_number_as_string_mismatch(self):
        """Debug number accessed as string."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_debug_array_as_object_mismatch(self):
        """Debug array accessed as object."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_debug_object_as_array_mismatch(self):
        """Debug object accessed as array."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_debug_null_type_mismatch(self):
        """Debug null type mismatch."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_debug_boolean_type_coercion(self):
        """Debug boolean type coercion."""
        # TODO: Implement when JsonStreamParser is available
        pass
