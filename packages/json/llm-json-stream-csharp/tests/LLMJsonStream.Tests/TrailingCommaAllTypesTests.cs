using Xunit;

namespace LLMJsonStream.Tests;

public class TrailingCommaAllTypesTests
{
    [Theory(Skip = "TODO: Port trailing_comma_all_types_test.dart cases")]
    [InlineData("trailing comma after string in array")]
    [InlineData("trailing comma after number in array")]
    [InlineData("trailing comma after decimal number in array")]
    [InlineData("trailing comma after boolean true in array")]
    [InlineData("trailing comma after boolean false in array")]
    [InlineData("trailing comma after null in array")]
    [InlineData("trailing comma after nested object in array")]
    [InlineData("trailing comma after nested array in array")]
    [InlineData("trailing comma after empty string in array")]
    [InlineData("trailing comma after zero in array")]
    [InlineData("trailing comma after negative number in array")]
    [InlineData("trailing comma after string value in object")]
    [InlineData("trailing comma after number value in object")]
    [InlineData("trailing comma after decimal value in object")]
    [InlineData("trailing comma after boolean true value in object")]
    [InlineData("trailing comma after boolean false value in object")]
    [InlineData("trailing comma after null value in object")]
    [InlineData("trailing comma after nested object value in object")]
    [InlineData("trailing comma after nested array value in object")]
    [InlineData("trailing comma after empty string value in object")]
    [InlineData("trailing comma after zero value in object")]
    [InlineData("trailing comma after negative number value in object")]
    [InlineData("object with trailing comma inside array with trailing comma")]
    [InlineData("array with trailing comma inside object with trailing comma")]
    [InlineData("deeply nested with trailing commas at every level")]
    [InlineData("all types with trailing commas in single array")]
    [InlineData("all types with trailing commas in single object")]
    public void TrailingCommaAllTypes_Scenarios(string caseName)
    {
        _ = caseName;
    }
}
