class Session
{

    /**
     * Indicates, that a file was modified by the user, since it was last saved or loaded.
     */
    public static uint FLAGS_MODIFIED = 1 << 0;

    /**
     * Indicates, that a file was changed by another user or program.
     */
    public static uint FLAGS_CONFLICT = 1 << 1;

    public FileManager files { public get; internal set; default = new FileManager(); }

    public FileManager.File? master { public get; public set; }

    public Session()
    {
        files.new_file_flags = FLAGS_MODIFIED;
    }

}
