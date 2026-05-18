using Xunit;

namespace LLMJsonStream.Tests;

public class TypeMismatchDebugTests
{
    [Theory(Skip = "TODO: Port type_mismatch_debug.dart cases")]
    [InlineData("Test: {\"test\":[1,2]} trying to getNumberProperty(\"test\")")]
    [InlineData("Test: {\"test\":[1,2,]} trying to getNumberProperty(\"test\")")]
    public void TypeMismatchDebug_Scenarios(string caseName)
    {
    }
}
