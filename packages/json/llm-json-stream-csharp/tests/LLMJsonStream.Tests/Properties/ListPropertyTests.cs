using Xunit;

namespace LLMJsonStream.Tests.Properties;

public class ListPropertyTests
{
    [Theory(Skip = "TODO: Port list_property_test.dart cases")]
    [InlineData("simple list - get entire list")]
    [InlineData("list of strings")]
    [InlineData("array index access - simple")]
    [InlineData("array of objects - access nested property")]
    [InlineData("empty array")]
    [InlineData("nested arrays")]
    [InlineData("mixed-type array")]
    [InlineData("chainable property access - get list then chain")]
    [InlineData("list iteration with onElement")]
    [InlineData("deeply nested structure with lists and maps")]
    [InlineData("list with whitespace")]
    [InlineData("single element array")]
    [InlineData("onElement can be set via getListProperty on MapPropertyStream")]
    [InlineData("onElement can be set via getListProperty on ListPropertyStream")]
    [InlineData("onElement callback receives correct property stream type")]
    [InlineData("List onElement - Object Futures")]
    [InlineData("List onElement - Object Futures (Flutter App Scenario)")]
    [InlineData("List onElement - Premature Future Access Bug")]
    [InlineData("List onElement - EXACT Flutter Bug Reproduction")]
    [InlineData("List onElement - Flutter Timing Bug (Parser before Callback)")]
    [InlineData("List onElement - Early Stream Close Bug")]
    [InlineData("List onElement - EXACT FLUTTER SCENARIO - Maps Resolve Immediately")]
    [InlineData("List onElement - AWAIT in onElement callback")]
    [InlineData("List onElement - Broadcast Stream (Flutter App Uses This)")]
    [InlineData("List onElement - Check for Empty Map Bug")]
    [InlineData("List property `listPropertyStream.stream` test")]
    public void ListProperty_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
