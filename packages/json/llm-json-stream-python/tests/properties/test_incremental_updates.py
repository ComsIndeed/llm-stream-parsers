"""Incremental updates tests."""

import pytest
from tests.utils.stream_utils import stream_text_in_chunks


class TestIncrementalUpdates:
    """Incremental updates test suite for properties."""

    @pytest.mark.asyncio
    async def test_string_emits_on_each_chunk(self):
        """Test string emits on each chunk."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_string_emits_buffered_chunks(self):
        """Test string emits buffered chunks."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_string_does_not_emit_unbuffered(self):
        """Test string does not emit unbuffered."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_maps_emit_buffered_latest_value_only(self):
        """Test maps emit buffered (latest value only)."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_maps_unbuffered_does_not_replay(self):
        """Test maps unbuffered does not replay."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_lists_emit_buffered_latest_value_only(self):
        """Test lists emit buffered (latest value only)."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_lists_unbuffered_does_not_replay(self):
        """Test lists unbuffered does not replay."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_incremental_stream_updates(self):
        """Test incremental stream updates."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_buffered_vs_unbuffered_behavior(self):
        """Test buffered vs unbuffered behavior."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_late_subscription_behavior(self):
        """Test late subscription behavior."""
        # TODO: Implement when JsonStreamParser is available
        pass
