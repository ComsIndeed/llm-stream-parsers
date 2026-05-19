using Xunit;

namespace LLMJsonStream.Tests.Properties;

public class StringPropertyTests
{
    [Theory(Skip = "TODO: Port string_property_test.dart cases")]
    [InlineData("simple string value")]
    [InlineData("string with escape sequences - newline")]
    [InlineData("string with escape sequences - tab")]
    [InlineData("string with escaped quotes inside")]
    [InlineData("string with backslashes")]
    [InlineData("empty string")]
    [InlineData("string with Unicode/emoji")]
    [InlineData("nested string access with dot notation")]
    [InlineData("deeply nested string access")]
    [InlineData("string with multiple escape sequences")]
    public void StringProperty_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
