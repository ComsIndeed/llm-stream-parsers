using Xunit;

namespace LLMJsonStream.Tests;

public class ObservabilityTests
{
    [Theory(Skip = "TODO: Port observability_test.dart cases")]
    [InlineData("Parser emits rootStart and rootComplete events")]
    [InlineData("Parser emits propertyStart and propertyComplete for string")]
    [InlineData("Parser emits stringChunk events")]
    [InlineData("Parser emits listElementStart events")]
    [InlineData("Parser emits mapKeyDiscovered events")]
    [InlineData("Parser emits yapFiltered event when yap filter triggers")]
    [InlineData("Parser emits disposed event")]
    [InlineData("StringPropertyStream can set onLog callback")]
    [InlineData("MapPropertyStream can set onLog callback")]
    [InlineData("ListPropertyStream can set onLog callback")]
    [InlineData("Nested property logs are scoped to subtree")]
    [InlineData("onLog can be set via named parameter in constructor access")]
    [InlineData("Parser emits error event on type mismatch")]
    public void Observability_Scenarios(string caseName)
    {
    }
}
