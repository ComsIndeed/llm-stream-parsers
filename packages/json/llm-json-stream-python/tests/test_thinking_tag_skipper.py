"""Thinking tag skipper tests."""

import pytest
from tests.utils.stream_utils import stream_text_in_chunks


class TestThinkingTagSkipperBasicFunctionality:
    """Basic thinking tag skipper functionality tests."""

    @pytest.mark.asyncio
    async def test_skip_content_inside_think_tags(self):
        """Test skipping content inside default think tags."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_skip_content_inside_custom_tags(self):
        """Test skipping content inside custom tags."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_handle_json_without_thinking_tags(self):
        """Test handling JSON without any thinking tags."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_multiple_thinking_blocks(self):
        """Test multiple thinking blocks."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_thinking_blocks_with_tags_inside_json_strings(self):
        """Test thinking blocks with tags inside JSON string values."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_empty_thinking_blocks(self):
        """Test empty thinking blocks."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_nested_thinking_blocks(self):
        """Test nested thinking blocks."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_malformed_thinking_blocks(self):
        """Test malformed thinking blocks."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_thinking_blocks_split_across_chunks(self):
        """Test thinking blocks split across chunks."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_thinking_tag_case_sensitivity(self):
        """Test thinking tag case sensitivity."""
        # TODO: Implement when JsonStreamParser is available
        pass
