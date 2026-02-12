// Haversine Formula to Calculate Great Circle Distance between Two Lat/Lon Points
// Note: This calculates the distance in kilometers

cap prog drop geodist
program define geodist
    version 16.0
    syntax varlist(min=4 max=4), generate(name)
    
    tokenize `varlist'
    local lat1 `1'
    local lon1 `2'
    local lat2 `3'
    local lon2 `4'

    * Earth's radius in kilometers
    local R = 6371
    
    * Convert degrees to radians
    generate `generate' = `R' * 2 * asin(sqrt( ///
        sin((`lat2' - `lat1') * _pi/180 / 2)^2 + ///
        cos(`lat1' * _pi/180) * cos(`lat2' * _pi/180) * ///
        sin((`lon2' - `lon1') * _pi/180 / 2)^2 ///
    ))
end

* Example usage:
* geodist latitude1 longitude1 latitude2 longitude2, generate(distance_km)
* This will create a new variable 'distance_km' with the distance in kilometers