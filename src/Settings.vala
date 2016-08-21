public class Settings : Granite.Services.Settings
{

    public string current_session              { get; set; }
    public bool   horizontal_scroll_in_preview { get; set; }
    public bool   fit_preview_zoom_after_build { get; set; }
    
    public Settings()
    {
        base( "org.kostrykin.athena" );
    }

}

