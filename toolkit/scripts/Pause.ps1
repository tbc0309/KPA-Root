[CmdletBinding()]
param([ValidateSet('CN','EN')][string]$Language = 'CN')

$Prompt = if ($Language -eq 'CN') { '按回车键关闭窗口' } else { 'Press Enter to close this window' }
[void](Microsoft.PowerShell.Utility\Read-Host $Prompt)
