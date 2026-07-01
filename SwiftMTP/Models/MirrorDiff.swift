struct MirrorDiff
{
    // strays are files which exist on the truth source but do not exist on the listener (device that isnt the truth source)
    var strays : Dictionary<String, Bool>
    // merge conflict resoltuion needed
    var conflict : Dictionary<String, Bool>
}




