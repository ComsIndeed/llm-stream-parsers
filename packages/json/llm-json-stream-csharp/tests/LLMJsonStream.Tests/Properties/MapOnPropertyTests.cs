using Xunit;

namespace LLMJsonStream.Tests.Properties;

public class MapOnPropertyTests
{
    [Theory(Skip = "TODO: Port map_on_property_test.dart cases")]
    [InlineData("fires callback for each property in a map")]
    [InlineData("allows subscribing to property stream in callback")]
    [InlineData("works with nested maps")]
    [InlineData("fires before property value is complete")]
    [InlineData("handles maps with list properties")]
    [InlineData("multiple callbacks can be registered")]
    [InlineData("onProperty and stream work together")]
    public void MapOnProperty_Scenarios(string caseName)
    {
    }
}
