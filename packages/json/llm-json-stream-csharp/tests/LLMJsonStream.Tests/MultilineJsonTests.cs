using Xunit;

namespace LLMJsonStream.Tests;

public class MultilineJsonTests
{
    [Theory(Skip = "TODO: Port multiline_json_test.dart cases")]
    [InlineData("Debug: Show characters in multiline JSON")]
    [InlineData("Parse JSON with actual newline characters from triple-quoted string")]
    [InlineData("Parse simple multiline JSON")]
    [InlineData("Parse multiline array")]
    [InlineData("Parse multiline nested objects")]
    [InlineData("JSON with leading whitespace (newlines, spaces, tabs)")]
    [InlineData("Array with leading whitespace")]
    [InlineData("Windows-style line endings (CRLF)")]
    public void MultilineJson_Scenarios(string caseName)
    {
    }
}
