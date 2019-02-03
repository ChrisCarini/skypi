"""
The value of LOCAL_DATA_FILES_PATH can be obtained from:

    https://github.com/flightaware/dump1090/blob/master/debian/lighttpd/89-dump1090-fa.conf

In the block matching similar to:

    # Listen on port 8080 and serve the map there, too.
    $SERVER["socket"] == ":8080" {
      alias.url += (
        "/data/" => "/run/dump1090-fa/",
        "/" => "/usr/share/dump1090-fa/html/"
      )
    }

"""
LOCAL_DATA_FILES_PATH = "/run/dump1090-fa/"
