$cmdFileBaseName="delete_dev_2638"
$batch=0
$count=0

foreach ($dev in (cat unbound_notinsg_tdev.2638.txt)) {
    if( $count -eq 0 -or $count -gt 50 ) {

        $count=0
        $batch++
        $cmdFile=$cmdFileBaseName+"_" + $batch + ".txt"
        if( Test-Path $cmdFile ) { rm $cmdFile }

        "NEW FILE $cmdFile"
    }

    $dev

    "delete dev $dev;" | out-file -Encoding ascii -Append $cmdFile
    $count++
}