@{
    Id = 'air-mini'
    Name = 'AYANEO Pocket AIR Mini'
    PackageName = 'AYANEO_Pocket_AIR_Mini_Root_TEST'
    LauncherTitle = 'AYANEO Pocket AIR Mini'
    Models = @('GT78-VN')
    Devices = @('GT78-VN')
    Boards = @('k85v1_64')
    FastbootProductPattern = 'k85v1_64|GT78|BW02|MP40AY2'
    SerialPattern = '^BW02[A-Z0-9]+$'
    BuildPattern = '^MP40AY2-(\d{8})(?:_|$)'
    BootSize = 33554432
    ImageDirectory = 'images'
    FastbootConfirmKeyEn = 'Volume Up'
    FastbootConfirmKeyCn = '音量+'
}
