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
import 'dart:math';

Future<List<File>> pickMusicFolder() async {
  // Open folder picker
  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

  if (selectedDirectory == null) {
    return [];
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('music_directory', selectedDirectory); 

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

Future<String> getArtist(File song) async {
  try {
    Metadata metadata = await MetadataGod.readMetadata(file: song.path);
    return metadata.artist ?? 'Unknown Artist';
  } catch (e) {
    print('Error fetching artist: $e');
    return 'Unknown Artist';
  }
}

class MusicListPage extends StatefulWidget {
  const MusicListPage({super.key});

  @override
  _MusicListPageState createState() => _MusicListPageState();
}

Color containerColor = const Color.fromARGB(255, 75, 74, 74);
String? storedDirectory;

class _MusicListPageState extends State<MusicListPage> {
  List<File> songs = [];
  DirectoryWatcher? _directoryWatcher;
  StreamSubscription<WatchEvent>? _directoryWatcherSubscription;
  

  @override
  void initState() {
    super.initState();
    initializeMetadataGod(); 
    loadSongs();
  }

   Future<void> initializeMetadataGod() async {
    MetadataGod.initialize(); // Initialization of MetadataGod
  }

  int findDarkest(img.Image image) {
  double totalRed = 0;
  double totalGreen = 0;
  double totalBlue = 0;
  double totalAlpha = 0;
  int totalPixels = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      int color = image.getPixel(x, y);
      int red = img.getRed(color);
      int green = img.getGreen(color);
      int blue = img.getBlue(color);
      int alpha = img.getAlpha(color);
      totalRed += red * red;
      totalGreen += green * green;
      totalBlue += blue * blue;
      totalAlpha += alpha;
      totalPixels++;
    }
  }

  int avgRed = (sqrt(totalRed / totalPixels)).round();
  int avgGreen = (sqrt(totalGreen / totalPixels)).round();
  int avgBlue = (sqrt(totalBlue / totalPixels)).round();
  int avgAlpha = (totalAlpha / totalPixels).round();

  
  return img.getColor(avgRed, avgGreen, avgBlue, avgAlpha);
}


    Future<void> handleHover(File song) async {
    Uint8List? albumArt = await getAlbumArt(song);
    if (albumArt != null) {
      img.Image? albumArtImage = img.decodeImage(albumArt);

      if (albumArtImage != null) {
        int darkestColor = findDarkest(albumArtImage);

        // Update the state to change the gradient
        setState(() {
          containerColor = Color(darkestColor);
        });
      } else {
        print('Failed to decode image');
      }
    } else {
      setState(() {
        containerColor = Colors.grey;
      });
    }
  }


  void loadSongs() async {
    storedDirectory = await getStoredDirectory();
    storedDirectory ??= await selectDirectory();

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
    return prefs.getString('music_directory');
  }

  Future<String?> selectDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('music_directory', selectedDirectory); 
    }
    return selectedDirectory;
  }

  void watchDirectoryChanges(String directoryPath) {
    _directoryWatcher = DirectoryWatcher(directoryPath);
    _directoryWatcherSubscription = _directoryWatcher!.events.listen((event) {

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
            color: Colors.black,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Container(
                    width: 250,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 27, 26, 26),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(0),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                        topRight: Radius.circular(12.0),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Icon(
                          Icons.my_library_music_rounded,
                          size: 25.0,
                          color: Colors.grey,
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: 20,
                            top: 0,
                            bottom: 0,
                            right: 0,
                          ),
                          child: Text(
                            "Your Playlist",
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12.0),
                      bottomLeft: Radius.circular(0),
                      bottomRight: Radius.circular(0),
                      topRight: Radius.circular(0),
                    ),
                    gradient: LinearGradient(
                      begin: const Alignment(1, -1.5),
                      end: const Alignment(1, 1),
                      colors: [
                        containerColor, // Dynamic color
                        Colors.black,
                      ],
                    ),
                  ),
                  child: songs.isEmpty
                      ? const Center(child: Text("No songs found"))
                      : ListView.builder(
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            File song = songs[index];
                            return MouseRegion(
                              onEnter: (_) => handleHover(song),
                              child: ListTile(
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
                                        'assets/images/album_art_placeholder.jpg',
                                        width: 43,
                                        height: 43,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                  },
                                ),
                                title: Text(song.path.split(r'\').last),
                                textColor: Colors.white,
                                onTap: () => playSong(song),
                              ),
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
        builder: (context) => MusicPlayer(song: song, handleHover: handleHover,), // Pass the selected song
      ),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  File song;
  Function(File song) handleHover;
  MusicPlayer({super.key, required this.song, required this.handleHover});

  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  Image? coverArtImage;
  Directory musicDirectory = Directory(storedDirectory!); 
  List<FileSystemEntity> allFiles = [];
  int currentFileIndex = 0;  
  // Store the subscriptions
  StreamSubscription? durationSubscription;
  StreamSubscription? positionSubscription;
  StreamSubscription? playerStateSubscription;
  File currentSong = File('');
  String artist = 'Unknown Artist';

  @override
  void initState() {
    super.initState();
    // Load the music files from the directory
    allFiles = musicDirectory.listSync().where((file) => file.path.endsWith('.mp3')).toList();
    
    // Get the current song index based on the passed file
    currentFileIndex = allFiles.indexWhere((file) => file.path == widget.song.path);
    currentSong = File(allFiles[currentFileIndex].path);
    loadCoverArt();
    playSong();

    // Listen for changes in the duration
    durationSubscription = audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        duration = newDuration;
      });
    });

    // Listen for changes in the position
    positionSubscription = audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        position = newPosition;
      });
    });

    // Listen for player state changes
    playerStateSubscription = audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.completed) {
        _handleSongEnd();
      }
    });

  }
  

  Future<void> playSong() async {
  // Play the song at the current index
  await audioPlayer.play(DeviceFileSource(allFiles[currentFileIndex].path));
  artist = await getArtist(currentSong);
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

  Future<void> togglePlayback() async {
    if (isPlaying) {
      await pauseSong();
    } else {
      await playSong();
    }
  }

Future<void> nextSong() async {
  if (currentFileIndex < allFiles.length - 1) {
    setState(() {
      currentFileIndex++;
      currentSong = File(allFiles[currentFileIndex].path); 
    });
    artist = await getArtist(currentSong);
    await stopSong();
    loadCoverArt();
    widget.handleHover(currentSong);
    await playSong();
  }
}

Future<void> previousSong() async {
  if (currentFileIndex > 0) {
    setState(() {
      currentFileIndex--;
      currentSong = File(allFiles[currentFileIndex].path); 
    });
    artist = await getArtist(currentSong);
    await stopSong();
    loadCoverArt();
    widget.handleHover(currentSong); 
    await playSong();
  }
}

Future<void> _handleSongEnd() async {
  await nextSong();
}

 void loadCoverArt() async {
  Uint8List? albumArt = await getAlbumArt(File(allFiles[currentFileIndex].path));

  if (albumArt != null) {
    setState(() {
      coverArtImage = Image.memory(
        albumArt,
        fit: BoxFit.cover,
        width: 200,
        height: 200,
      );
    });
  } else {
    setState(() {
      coverArtImage = Image.asset(
        'assets/images/album_art_placeholder.jpg',
        fit: BoxFit.cover,
        width: 200,
        height: 200,
      );
    });
  }
}


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: containerColor,
      ),
      body: Stack(
        children: [
          Container(
            width: screenWidth,
            height: screenHeight - 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(1, -1.5),
                end: const Alignment(1, 1),
                colors: [
                  containerColor,
                  const Color.fromARGB(255, 29, 27, 27),
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 8.0,
                child: ClipRRect(
                  child: coverArtImage ?? const SizedBox(
                    width: 200,
                    height: 200,
                    //child: CircularProgressIndicator(),  // Loading indicator until image is ready
                  ),
                ),
              ),
              //song title
              Text(
                currentSong?.path.split(r'\').last.replaceAll('.mp3', '') ?? 'No song selected',
                style: const TextStyle(
                  fontSize: 20.0,
                  color: Colors.white,
                ),
              ),
              Text(
                artist,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.grey[350],
                ),
              ),
              Slider(
                min: 0,
                max: duration.inSeconds.toDouble(),
                activeColor: Colors.white,
                value: position.inSeconds.toDouble(),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await audioPlayer.seek(position);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous,
                      color: Colors.white,
                      ),
                    onPressed: previousSong,
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      ),
                    onPressed: togglePlayback,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next,
                      color: Colors.white,
                      ),
                    onPressed: nextSong,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    durationSubscription?.cancel();
    positionSubscription?.cancel();
    playerStateSubscription?.cancel();
    audioPlayer.dispose();
    super.dispose();
}

}



