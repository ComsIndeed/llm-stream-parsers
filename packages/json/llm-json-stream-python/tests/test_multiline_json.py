"""Multiline JSON tests."""

import pytest
from tests.utils.stream_utils import stream_text_in_chunks


class TestMultilineJSON:
    """Multiline JSON test suite."""

    @pytest.mark.asyncio
    async def test_json_with_newlines(self):
        """Test JSON with newlines."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_json_with_multiline_strings(self):
        """Test JSON with multiline strings."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_json_with_various_whitespace(self):
        """Test JSON with various whitespace."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_json_with_indentation(self):
        """Test JSON with indentation."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_json_without_whitespace(self):
        """Test minified JSON without whitespace."""
        # TODO: Implement when JsonStreamParser is available
        pass
