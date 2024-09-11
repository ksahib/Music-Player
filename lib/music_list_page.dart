import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:watcher/watcher.dart';
import 'package:metadata_god/metadata_god.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:async';

Future<List<File>> pickMusicFolder() async {
  // Open folder picker
  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

  if (selectedDirectory == null) {
    return [];
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('music_directory', selectedDirectory); // Corrected key to 'music_directory'

  // Get all files in the folder
  Directory dir = Directory(selectedDirectory);
  List<File> files = dir
      .listSync()
      .where((item) => item.path.endsWith('.mp3'))
      .map((item) => File(item.path))
      .toList();

  return files;
}

Future<Uint8List?> getAlbumArt(File song) async {
  try {
    Metadata metadata = await MetadataGod.readMetadata(file: song.path);
    return Uint8List.fromList(metadata.picture!.data);
  } catch (e) {
    print('Error fetching album art: $e');
    return null;
  }
}

class MusicListPage extends StatefulWidget {
  @override
  _MusicListPageState createState() => _MusicListPageState();
}

class _MusicListPageState extends State<MusicListPage> {
  List<File> songs = [];
  DirectoryWatcher? _directoryWatcher;
  StreamSubscription<WatchEvent>? _directoryWatcherSubscription;
  String? storedDirectory;

  @override
  void initState() {
    super.initState();
    initializeMetadataGod(); 
    loadSongs();
  }

   Future<void> initializeMetadataGod() async {
    MetadataGod.initialize(); // Initialization of MetadataGod
    print('MetadataGod initialized'); // Debugging output
  }

  int findDarkest(img.Image image) {
    int r = 255, g = 255, b = 255, a=255;

    for(int y = 0; y < image.height; y++) {
      for(int x = 0; x < image.width; x++) {
        int color = image.getPixel(x,y);
        int red = img.getRed(color);
        int green = img.getGreen(color);
        int blue = img.getBlue(color);
        int alpha = img.getAlpha(color);

        if(red < r) r = red;
        if(green < g) g = green;
        if(blue < b) b = blue;
        if(a < alpha) a = alpha;
      }
    }

    return img.getColor(r, g, b, a);
  }

  void loadSongs() async {
    storedDirectory = await getStoredDirectory();
    if (storedDirectory == null) {
      storedDirectory = await selectDirectory();
    }

    if (storedDirectory != null) {
      await loadSongsFromStoredDirectory(storedDirectory!);
      watchDirectoryChanges(storedDirectory!);
    }
  }

  Future<void> loadSongsFromStoredDirectory(String directoryPath) async {
    Directory dir = Directory(directoryPath);
    List<File> files = dir
        .listSync()
        .where((item) => item.path.endsWith('.mp3'))
        .map((item) => File(item.path))
        .toList();

    setState(() {
      songs = files;
    });
  }

  Future<String?> getStoredDirectory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('music_directory'); // Corrected key to 'music_directory'
  }

  Future<String?> selectDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('music_directory', selectedDirectory); // Corrected key to 'music_directory'
    }
    return selectedDirectory;
  }

  void watchDirectoryChanges(String directoryPath) {
    print('Watching directory: $directoryPath'); // Debugging line
    _directoryWatcher = DirectoryWatcher(directoryPath);
    _directoryWatcherSubscription = _directoryWatcher!.events.listen((event) {
      print('Directory change detected: ${event.type}'); // Debugging line

      if (event.type == ChangeType.ADD || event.type == ChangeType.REMOVE || event.type == ChangeType.MODIFY) {
        loadSongsFromStoredDirectory(directoryPath); // Refresh the list of songs
      }
    });
  }

  @override
  void dispose() {
    _directoryWatcherSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: <Widget>[
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[700],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 250,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    gradient: const LinearGradient(
                      begin: Alignment(1,-1.5),
                      end: Alignment(1,1),
                      colors: [
                        Colors.cyan,
                        Colors.black,
                      ],
                ),
                  ),
                  child: songs.isEmpty
                ? Center(child: Text("No songs found"))
                : ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      File song = songs[index];
                      return ListTile(
                        leading: FutureBuilder<Uint8List?>(
                          future: getAlbumArt(song),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.memory(
                                snapshot.data!,
                                width: 43,
                                height: 43,
                                fit: BoxFit.cover,
                              );
                            } else {
                              return Image.asset(
                                'assets/images/album_art_placeholder.jpg', // Default image
                                width: 43,
                                height: 43,
                                fit: BoxFit.cover,
                              );
                            }
                          },
                        ),
                        title: Text(song.path.split(r'\').last), // Fixed backslash issue
                        textColor: Colors.white,
                        onTap: () => playSong(song),
                        
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void playSong(File song) {
    // Navigate to the MusicPlayer screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MusicPlayer(song: song), // Pass the selected song
      ),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  final File song;
  const MusicPlayer({Key? key, required this.song}) : super(key: key);

  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    playSong();
  }

  Future<void> playSong() async {
    // Play the song using the DeviceFileSource (local file)
    await audioPlayer.play(DeviceFileSource(widget.song.path));
    setState(() {
      isPlaying = true;
    });
  }

  Future<void> pauseSong() async {
    await audioPlayer.pause();
    setState(() {
      isPlaying = false;
    });
  }

  Future<void> stopSong() async {
    await audioPlayer.stop();
    setState(() {
      isPlaying = false;
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.path.split(r'\').last), // Fixed backslash issue
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isPlaying ? "Playing..." : "Paused"),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.play_arrow),
                onPressed: isPlaying ? null : playSong,
              ),
              IconButton(
                icon: Icon(Icons.pause),
                onPressed: isPlaying ? pauseSong : null,
              ),
              IconButton(
                icon: Icon(Icons.stop),
                onPressed: stopSong,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
