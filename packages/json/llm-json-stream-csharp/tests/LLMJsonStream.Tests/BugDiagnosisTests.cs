using Xunit;

namespace LLMJsonStream.Tests;

public class BugDiagnosisTests
{
    [Theory(Skip = "TODO: Port bug_diagnosis_test.dart cases")]
    [InlineData("Reproduce bug with minimal JSON")]
    [InlineData("Exact reproduction - chunk boundary in list string")]
    [InlineData("Test the actual failing JSON with chunk 25")]
    [InlineData("Concluding test for the bug")]
    public void BugDiagnosis_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
