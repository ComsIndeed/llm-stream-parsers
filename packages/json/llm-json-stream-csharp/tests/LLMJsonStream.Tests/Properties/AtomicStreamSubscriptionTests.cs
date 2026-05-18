using Xunit;

namespace LLMJsonStream.Tests.Properties;

public class AtomicStreamSubscriptionTests
{
    [Theory(Skip = "TODO: Port atomic_stream_subscription_test.dart cases")]
    [InlineData("Boolean stream can be subscribed to and emits value")]
    [InlineData("Number stream can be subscribed to and emits value")]
    [InlineData("Null stream can be subscribed to and emits value")]
    [InlineData("Multiple atomic streams can be subscribed to simultaneously")]
    [InlineData("Atomic streams in nested objects work correctly")]
    [InlineData("Atomic streams in arrays work correctly")]
    [InlineData("Atomic stream with chunked JSON delivery")]
    public void AtomicStreamSubscription_Scenarios(string caseName)
    {
    }
}
