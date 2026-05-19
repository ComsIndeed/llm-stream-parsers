using Xunit;

namespace LLMJsonStream.Tests;

public class CriticalBugTests
{
    [Theory(Skip = "TODO: Port critical_bug_test.dart cases")]
    [InlineData("CRITICAL: Single character value with huge chunk")]
    [InlineData("CRITICAL: Two character value with huge chunk")]
    [InlineData("CRITICAL: Empty string with huge chunk")]
    [InlineData("CRITICAL: Single digit number with huge chunk")]
    [InlineData("CRITICAL: Boolean value with huge chunk")]
    [InlineData("CRITICAL: Null value with huge chunk")]
    [InlineData("CRITICAL: Compare small value - small chunk vs large chunk")]
    [InlineData("CRITICAL: Very small value (1 char) vs very large chunk (10000)")]
    [InlineData("CRITICAL: Multiple tiny values with single massive chunk")]
    [InlineData("CRITICAL: Check if onChunkEnd matters when chunk > value")]
    [InlineData("chunk size 1000x larger than value")]
    [InlineData("chunk size 10000x larger than value")]
    [InlineData("instant delivery (0ms) with massive chunk")]
    public void CriticalBug_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
