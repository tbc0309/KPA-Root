@{
    Id = 'pocket-advance'
    Name = 'KONKR Pocket Advance'
    PackageName = 'KPA_Root'
    LauncherTitle = 'KONKR Pocket Advance'
    Models = @('GT78-VN')
    Devices = @('GT78-VN')
    Boards = @('k85v1_64')
    FastbootProductPattern = 'k85v1_64|GT78|BW03'
    SerialPattern = '^BW03[A-Z0-9]+$'
    BuildPattern = '^BW03_(\d{8})(?:_|$)'
    BootSize = 33554432
    ImageDirectory = 'images'
    FastbootConfirmKeyEn = 'Volume Up (MODE to the right of L2)'
    FastbootConfirmKeyCn = '音量+（L2 右侧 MODE）'
}
