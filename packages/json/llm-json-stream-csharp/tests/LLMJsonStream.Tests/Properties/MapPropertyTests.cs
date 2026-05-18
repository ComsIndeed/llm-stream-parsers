using Xunit;

namespace LLMJsonStream.Tests.Properties;

public class MapPropertyTests
{
    [Theory(Skip = "TODO: Port map_property_test.dart cases")]
    [InlineData("simple flat map - get entire map")]
    [InlineData("get specific property from flat map")]
    [InlineData("nested map access - single level")]
    [InlineData("nested map access - deep path")]
    [InlineData("very deeply nested map")]
    [InlineData("empty map")]
    [InlineData("map with mixed types")]
    [InlineData("chainable property access - get map then chain")]
    [InlineData("map with nested maps and mixed content")]
    [InlineData("multiple maps at same level")]
    [InlineData("map with whitespace between tokens")]
    [InlineData("Map property `mapPropertyStream.stream` test")]
    public void MapProperty_Scenarios(string caseName)
    {
    }
}
