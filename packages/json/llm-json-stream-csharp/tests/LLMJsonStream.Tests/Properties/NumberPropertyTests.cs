using Xunit;

namespace LLMJsonStream.Tests.Properties;

public class NumberPropertyTests
{
    [Theory(Skip = "TODO: Port number_property_test.dart cases")]
    [InlineData("simple integer")]
    [InlineData("negative integer")]
    [InlineData("decimal number")]
    [InlineData("scientific notation")]
    [InlineData("negative scientific notation")]
    [InlineData("zero")]
    [InlineData("large integer")]
    [InlineData("nested number access")]
    [InlineData("deeply nested number access")]
    [InlineData("decimal with trailing zeros")]
    [InlineData("number as num type")]
    public void NumberProperty_Scenarios(string caseName)
    {
    }
}
