using Xunit;

namespace LLMJsonStream.Tests.Properties;

public class IncrementalTests
{
    [Theory(Skip = "TODO: Port incremental_test.dart cases")]
    [InlineData("String emits on each chunk")]
    [InlineData("String emits buffered chunks")]
    [InlineData("String does not emit unbuffereds")]
    [InlineData("Maps emit buffered (latest value only)")]
    [InlineData("Maps unbuffered does not replay")]
    [InlineData("Lists emit buffered (latest value only)")]
    [InlineData("Lists unbuffered does not replay")]
    [InlineData("Nested map in list emits on each chunk")]
    public void Incremental_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
