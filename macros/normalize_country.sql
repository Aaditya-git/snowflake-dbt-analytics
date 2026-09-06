{#
    Conform free-text country values to ISO 3166-1 alpha-2.

    The source system has a text box, not a dropdown, so the same country arrives as
    "USA", "United States" and "us". Anything unrecognised becomes 'XX' rather than
    being passed through -- an explicit unknown is testable, a passthrough is not.

    Driven from a dict so adding a spelling is a one-line change, and so the mapping
    is readable as data instead of as a fifty-branch CASE.
#}
{% macro normalize_country(column_name) %}
    {%- set country_map = {
        'US': ['US', 'USA', 'U.S.', 'U.S.A.', 'UNITED STATES', 'UNITED STATES OF AMERICA'],
        'CA': ['CA', 'CAN', 'CANADA'],
        'BR': ['BR', 'BRA', 'BRAZIL', 'BRASIL'],
        'KR': ['KR', 'SOUTH KOREA', 'KOREA, REPUBLIC OF', 'REPUBLIC OF KOREA'],
        'IT': ['IT', 'ITA', 'ITALY', 'ITALIA'],
        'FR': ['FR', 'FRA', 'FRANCE'],
        'DE': ['DE', 'DEU', 'GERMANY', 'DEUTSCHLAND'],
        'ES': ['ES', 'ESP', 'SPAIN', 'ESPANA'],
        'PL': ['PL', 'POL', 'POLAND', 'POLSKA'],
        'GH': ['GH', 'GHA', 'GHANA'],
        'NG': ['NG', 'NGA', 'NIGERIA']
    } -%}
    case upper(trim({{ column_name }}))
    {%- for iso_code, spellings in country_map.items() %}
        {%- for spelling in spellings %}
        when '{{ spelling }}' then '{{ iso_code }}'
        {%- endfor %}
    {%- endfor %}
        else 'XX'
    end
{% endmacro %}
