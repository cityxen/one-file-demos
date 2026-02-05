
import sys
import os

import struct
cwd=os.getcwd()
prg_start=0x0801
chunk_data=[
    ["prg",0x0801,0x0cff],
    ["clr",0x0d00,0x0dff],
    ["chr",0x1000,0x1fff],
    ["kla",0x2000,0x4710],
    ["sid",0x5000,0x5fff],
    ["scr",0x6000,0x6fff]
    ]

if len(sys.argv) > 1:
    filename = cwd+"\\"+sys.argv[1]
    print(f"FILENAME: {filename}!")
else:
    exit()

''' Get file data in '''
try:
    with open(filename, 'rb') as file:
        content = file.read()
except FileNotFoundError:
    print(f"Error: The file '{file_path}' was not found.")
except Exception as e:
    print(f"An error occurred: {e}")

sl=content[0]+(content[1]*256)
print(f"STARTING LOCATION: {sl}")

'''
Memory Map
----------
Default-segment:
  $0801-$0cff Main Program
  $0d00-$0d31 Color Cycle Data
  $1000-$1fff Char Set Data
  $2000-$4710 Img Data
  $5000-$5f7e Music
  $6000-$6a6c Scroll Text Data
'''
def extract_raw_c64_chunks(file_path, address_list):
    with open(file_path, 'rb') as f:
        for chunk_id, start, end in address_list:
            file_start = (start-prg_start)
            length = (end-prg_start) - (start-prg_start) + 1
            print(f"file_start {file_start} length {length}")
            if( (chunk_id=="prg") | (chunk_id=="sid")):
                f.seek(file_start)
            else:
                f.seek(file_start+2)
            raw_chunk = f.read(length)
            output_name = f"{file_path}.{start:04X}.{chunk_id[:3]}"
            with open(output_name, 'wb') as f_out:
                f_out.write(raw_chunk)
            print(f"Exported {len(raw_chunk)} raw bytes to {output_name}")

extract_raw_c64_chunks(filename, chunk_data)
