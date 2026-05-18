using Xunit;

namespace LLMJsonStream.Tests;

public class TrailingCommaDebugTests
{
    [Theory(Skip = "TODO: Port trailing_comma_debug.dart cases")]
    [InlineData("Test 1: {\"test\":[1,2,]}")]
    [InlineData("Test 2: {\"test\":[1,2,]} with chunk size 5")]
    [InlineData("Test 3: {\"test\":[1,2,]} with chunk size 1")]
    [InlineData("Test 4: {\"test\":[1,2,]} getting test[0] with chunk size 1")]
    [InlineData("Test 5: {\"test\":1} getting test as NUMBER")]
    [InlineData("Test 6: Object inside array with trailing comma")]
    public void TrailingCommaDebug_Scenarios(string caseName)
    {
    }
}
