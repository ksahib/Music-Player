import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:metadata_god/metadata_god.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:io';

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

Future<List<File>> loadSongsFromStoredDirectory() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? storedDirectory = prefs.getString('music_directory');

  if (storedDirectory == null) {
    // If no directory is stored, return an empty list
    return [];
  }

  // Load songs from the stored directory
  Directory dir = Directory(storedDirectory);
  List<File> files = dir
      .listSync()
      .where((item) => item.path.endsWith('.mp3'))
      .map((item) => File(item.path))
      .toList();

  return files;
}


Future<Uint8List?> getAlbumArt(File song) async {
  try {
    Metadata metadata = await MetadataGod.readMetadata(file:song.path);
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

  @override
  void initState() {
    super.initState();
    loadSongs();
  }

  void loadSongs() async {
    List<File> files = await loadSongsFromStoredDirectory();
    
    // If no songs are found, prompt user to select a folder
    if (files.isEmpty) {
      files = await pickMusicFolder();
    }
    
    setState(() {
      songs = files;
    });
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
        songs.isEmpty
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
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          );
                        } else {
                          return Image.asset(
                            'assets/images/album_art_placeholder.jpg', // Default image
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          );
                        }
                      },
                    ),
                    title: Text(song.path.split(r'\').last),
                    textColor: Colors.white,
                    onTap: () => playSong(song),
                  );
                },
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
        title: Text(widget.song.path.split(r'\').last),
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
