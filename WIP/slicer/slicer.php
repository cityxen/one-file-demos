<?php

function el($x) {
    echo "$x\n\r";
}

/* Memory Map
----------
Default-segment:
  $0801-$080c Basic
  $080e-$080d Basic End
  $0810-$0adb Main Program
  $0d00-$0d31 Color Cycle Data
  $1000-$1fff Char Set Data
  $2000-$4710 Img Data
  $5000-$5f7e Music
  $6000-$6a6c Scroll Text Data   */
$prg_start=0x0801;
$chunk_data=array(
    array("PRG BIN ",0x0801,0x0cff),
    array("CLR CYCL",0x0d00,0x0dff),
    array("CHAR SET",0x1000,0x1fff),
    array("KOALA   ",0x2000,0x4710),
    array("SID     ",0x5000,0x5fff),
    array("SCRL TXT",0x6000,0x7000)
);

$dir=getcwd();
$file="$dir\\$argv[1]";

el("Program:".$file);
el(filesize($file));

$fdata=file_get_contents($file);

$st=intval($fdata[0])+intval($fdata[1]*256);
el("[$prg_start] ... [$st]");

foreach ($chunk_data as $cd) {
    el("CHUNK: ".$cd[0]." ( START:".$cd[1]." - END  :".$cd[2].")" );

}


