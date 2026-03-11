@{
    # Module identity
    ModuleVersion     = '1.0.0'
    GUID              = 'fae71c0b-eca7-44b8-a9b2-695671d84e94'
    RootModule        = 'Start-mJig.psm1'

    # Authorship
    Author            = 'ziaprazid0ne'
    CompanyName       = ''
    Copyright         = 'CC BY-ND 4.0 -- https://creativecommons.org/licenses/by-nd/4.0/'
    Description       = 'Feature-rich PowerShell mouse jiggler with a console-based TUI. Keeps your system active with natural-looking mouse movements and intelligent user input detection.'

    # Compatibility
    PowerShellVersion = '5.1'

    # Exports -- only the public entry point is exposed
    FunctionsToExport = @('Start-mJig')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Pre-load the Windows.Forms assembly so it is available before the module runs
    RequiredAssemblies = @('System.Windows.Forms')

    # Module metadata
    PrivateData = @{
        PSData = @{
            Tags       = @('mouse-jiggler', 'tui', 'automation', 'windows')
            ProjectUri = 'https://github.com/ziaprazid0ne/mJig'
        }
    }
}
