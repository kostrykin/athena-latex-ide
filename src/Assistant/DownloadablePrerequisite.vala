private static const int ASSISTANT_DOWNLOADABLE_PREREQUISITE_BUFFER_SIZE = 2 << 14; // 16 KiB

namespace Assistant
{

    public class DownloadablePrerequisite : AbstractPrerequisite
    {

        public string filename;
        public string url;
        public string download_dir;
        public Gee.Set< string > search_dirs { get; private set; default = new Gee.HashSet< string >(); }
        private Prerequisite.Status? status = null;
        private string status_details = "";

        public DownloadablePrerequisite( string filename, string url, string download_dir )
        {
            this.filename = filename;
            this.url = url;
            this.download_dir = download_dir;
            search_dirs.add( download_dir );
        }

        public override Prerequisite.Status check_status()
        {
            if( filename.length == 0 )
            {
                warning( "Empty filename is prerequisite" );
                return Status.UNKNOWN;
            }
            if( search_dirs.size == 0 )
            {
                warning( "Filename without search directories is prerequisite" );
                return Status.UNKNOWN;
            }
            foreach( var search_dir in search_dirs )
            {
                var file_path = Path.build_path( Path.DIR_SEPARATOR_S, search_dir, filename );
                if( FileUtils.test( file_path, FileTest.IS_REGULAR | FileTest.EXISTS ) )
                {
                    status = Prerequisite.Status.FULFILLED;
                    set_status_details( "Found at %s".printf( file_path ) );
                    break;
                }
            }
            return Prerequisite.Status.VIOLATED;
        }

        private void set_status_details( string status_details )
        {
            this.status_details = status_details;
            Idle.add( () =>
                {
                    notify_property( "status_details" );
                    return false;
                }
            );
        }
    
        public override string get_status_details()
        {
            return status_details;
        }

        protected override string get_default_name()
        {
            return filename;
        }
    
        public override bool is_fixable()
        {
            return filename.length > 0 && url.length > 0 && download_dir.length > 0;
        }
    
        public override async void fix() throws PrerequisiteError
        {
            base.fix();

            if( download_dir.length == 0 ) throw new PrerequisiteError.NOT_FIXABLE( "Unspecified download directory" );
            if(          url.length == 0 ) throw new PrerequisiteError.NOT_FIXABLE( "Unspecified download URL"       );

            /* Create download directory, where 493 is 755 in octal.
             */
            if( DirUtils.create_with_parents( download_dir, 493 ) < 0 ) throw new PrerequisiteError.NOT_FIXABLE( @"Can't create $download_dir" );

            SourceFunc callback = fix.callback;
            ThreadFunc< void* > run = () =>
            {
                download();
                Idle.add( (owned) callback ); // catches up at latest occasion of the `yield` keyword
                return null;
            };
            Thread.create< void* >( run, false );

            yield; // pauses the execution of this method until `fix.callback` is called
        }

        /**
         * Downloads `url` to `download_dir/filename`.
         */
        private void download()
        {
            set_status_details( "Downloading %s".printf( url ) );

            var session = new Soup.Session();
            var input   = session.request( url ).send();
            var path    = Path.build_path( Path.DIR_SEPARATOR_S, download_dir, filename );
            var file    = File.new_for_path( path );
            var output  = file.replace( null, false, FileCreateFlags.NONE, null );

            ssize_t read;
            uint8 buffer[ ASSISTANT_DOWNLOADABLE_PREREQUISITE_BUFFER_SIZE ];
            while( ( read = input.read( buffer ) ) > 0 ) output.write( buffer[ 0 : read ] );

            set_status_details( "Downloaded to %s".printf( path ) );
        }

    }

}

