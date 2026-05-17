"""Disposal tests."""

import pytest
from tests.utils.stream_utils import stream_text_in_chunks


class TestDisposal:
    """Disposal and resource cleanup test suite."""

    @pytest.mark.asyncio
    async def test_dispose_clears_resources(self):
        """Test that dispose clears resources."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_dispose_stops_listening(self):
        """Test that dispose stops listening."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_multiple_dispose_calls(self):
        """Test multiple dispose calls are safe."""
        # TODO: Implement when JsonStreamParser is available
        pass

    @pytest.mark.asyncio
    async def test_no_errors_after_dispose(self):
        """Test no errors occur after dispose."""
        # TODO: Implement when JsonStreamParser is available
        pass
