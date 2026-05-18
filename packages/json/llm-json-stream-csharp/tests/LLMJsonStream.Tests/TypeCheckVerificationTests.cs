using Xunit;

namespace LLMJsonStream.Tests;

public class TypeCheckVerificationTests
{
    [Theory(Skip = "TODO: Port type_check_verification.dart scenarios")]
    [InlineData("Shorthand methods return correct types")]
    [InlineData("Chaining works correctly on MapPropertyStream")]
    public void TypeCheckVerification_Scenarios(string caseName)
    {
    }
}
