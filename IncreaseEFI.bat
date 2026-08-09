@echo off

echo list disk > dp.txt
echo select disk 0 >> dp.txt
echo list part >> dp.txt
echo create partition efi >> dp.txt
echo format quick fs=FAT32 >> dp.txt
echo assign letter=p >> dp.txt
echo list volume >> dp.txt
echo list partition >> dp.txt

diskpart /s dp.txt

del dp.txt

bcdboot C:\Windows /s P: /f UEFI

pause