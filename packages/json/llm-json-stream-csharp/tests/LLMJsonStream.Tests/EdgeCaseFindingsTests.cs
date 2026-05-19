using Xunit;

namespace LLMJsonStream.Tests;

public class EdgeCaseFindingsTests
{
    [Theory(Skip = "TODO: Port edge_case_findings_test.dart cases")]
    [InlineData("chunk boundary splitting markdown wrapper - KNOWN TO FAIL")]
    [InlineData("chunk boundary splitting <think> tag")]
    [InlineData("chunk boundary splitting JSON structure")]
    [InlineData("chunk splits between : and value")]
    [InlineData("chunk splits in middle of string value")]
    [InlineData("chunk splits in middle of number")]
    [InlineData("chunk splits array elements")]
    [InlineData("leading comma in array - actual behavior")]
    [InlineData("leading comma in object - actual behavior")]
    [InlineData("double leading commas")]
    [InlineData("markdown containing { should be skipped")]
    [InlineData("what if { appears in preamble text?")]
    [InlineData("JSON-like syntax in preamble")]
    [InlineData("empty strings everywhere")]
    [InlineData("zero values everywhere")]
    [InlineData("very long string value")]
    [InlineData("very large number")]
    [InlineData("very small decimal")]
    public void EdgeCaseFindings_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
