import 'package:flutter/material.dart';

void main() {
  runApp(HeartGuardApp());
}

class HeartGuardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeartGuard',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'Inter',
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserInfo(),
            SizedBox(height: 20),
            StartUsingHeartGuard(),
            SizedBox(height: 20),
            RecentReports(),
            SizedBox(height: 20),
            MyCareNetwork(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(),
    );
  }
}

class UserInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              Text('Omar Galal',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Text('Age: 21 yrs', style: TextStyle(color: Colors.white)),
              Text('Gender: Male', style: TextStyle(color: Colors.white)),
              Text('User  ID: 3356635915',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          CircleAvatar(
            backgroundImage: NetworkImage(
                'https://scontent.fcai20-5.fna.fbcdn.net/v/t39.30808-6/438093058_1821432605011791_3365138268134900039_n.jpg?_nc_cat=101&ccb=1-7&_nc_sid=6ee11a&_nc_ohc=JMMyRq09dpYQ7kNvgH4THDz&_nc_zt=23&_nc_ht=scontent.fcai20-5.fna&_nc_gid=AJckkZKsu6itvF31tUCfypT&oh=00_AYDW3nP05zx0Y5xxUpDhVHzGP8wgw2q_bkJuEDVrBIhuLg&oe=67634CDA'),
            radius: 30,
          ),
        ],
      ),
    );
  }
}

class StartUsingHeartGuard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text('Start using HeartGuard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text(
              'Get Real-Time Analysis of your heart sound and detect if there\'s any abnormality',
              textAlign: TextAlign.center),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ReportsPage()));
            },
            icon: Icon(Icons.upload),
            label: Text('Upload Sound'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecentReports extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Reports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ReportCard(
          date: '12 Dec 2024',
          title: 'A Comprehensive Health Analysis Report',
          analysis: 'Heart Sound Analysis',
          score: 'Normal',
        ),
        SizedBox(height: 10),
        ReportCard(
          date: '22 Nov 2024',
          title: 'Monthly Routine Checkup with Dr. Robert Dunn',
          analysis: 'Heart Sound Analysis',
          score: 'Normal',
        ),
      ],
    );
  }
}

class ReportCard extends StatelessWidget {
  final String date;
  final String title;
  final String analysis;
  final String score;

  ReportCard(
      {required this.date,
      required this.title,
      required this.analysis,
      required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date: $date', style: TextStyle(fontSize: 14)),
          Text(title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(analysis, style: TextStyle(fontSize: 14)),
          Text('Health Score: $score',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.share, color: Colors.grey),
              SizedBox(width: 10),
              Icon(Icons.download, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}

class MyCareNetwork extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Care Network',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            CareNetworkMember(
              name: 'Dr. Steve John',
              role: 'Endocrinologist',
              imageUrl:
                  'https://storage.googleapis.com/a1aa/image/tbNnQMDrE54sJpJmSqoHfszWek7FKUdR5A9yg3f28OeLzErPB.jpg',
            ),
            CareNetworkMember(
              name: 'Juliana',
              role: 'Health Coach',
              imageUrl:
                  'https://storage.googleapis.com/a1aa/image/nWwS15vKbnKIN5y0mpnyMc2YEMMh4XT7vMissMqfNFacmY9JA.jpg',
            ),
            CareNetworkMember(
              name: 'STV Med',
              role: 'D Clinic',
              imageUrl:
                  'https://storage.googleapis.com/a1aa/image/55IU44Wz8Y62HlO703oy0pUvz1IERV2GEl7FZF7RUpeZmY9JA.jpg',
            ),
            CareNetworkMember(
              name: 'Dr. Muling',
              role: 'Cardiologist',
              imageUrl:
                  'https://storage.googleapis.com/a1aa/image/psgn5Ba8uLIEHFtfyweOQNh7QhVRahto4dfwUTgfourYzErPB.jpg',
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ],
    );
  }
}

class CareNetworkMember extends StatelessWidget {
  final String name;
  final String role;
  final String imageUrl;

  CareNetworkMember(
      {required this.name, required this.role, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
          radius: 30,
        ),
        SizedBox(height: 5),
        Text(name, style: TextStyle(fontSize: 12)),
        Text(role, style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class BottomNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home, color: Colors.purple),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.file_copy, color: Colors.grey),
          label: 'Reports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite, color: Colors.grey),
          label: 'Health',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.info, color: Colors.grey),
          label: 'Info',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat, color: Colors.grey),
          label: 'Chat',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => HomePage()));
            break;
          case 1:
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => ReportsPage()));
            break;
          case 2:
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => HealthPage()));
            break;
          case 3:
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => InfoPage()));
            break;
          case 4:
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => ChatPage()));
            break;
        }
      },
    );
  }
}

class ReportsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Get your Heart Sound Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Image.network(
                'https://storage.googleapis.com/a1aa/image/XdXreP4NHrX0YK1jlTXvWKnsRKc5Kl8K52Mf9uWg2Ng1Mx6TA.jpg',
                height: 300),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => HealthPage()));
              },
              icon: Icon(Icons.upload),
              label: Text('Upload Heart Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text('* Use original report template only',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class HealthPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Health'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Heart Sound Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ReportCard(
              date: '12 Dec 2024',
              title: 'A Comprehensive Health Analysis Report',
              analysis: 'Heart Sound Analysis',
              score: 'Normal',
            ),
            SizedBox(height: 20),
            ReportCard(
              date: '22 Nov 2024',
              title: 'Monthly Routine Checkup with Dr. Robert Dunn',
              analysis: 'Heart Sound Analysis',
              score: 'Normal',
            ),
          ],
        ),
      ),
    );
  }
}

class InfoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Info'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserInfo(),
            SizedBox(height: 20),
            Text('Medical History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ReportCard(
              date: '12 Dec 2024',
              title: 'A Comprehensive Health Analysis Report',
              analysis: 'Heart Sound Analysis',
              score: 'Normal',
            ),
            SizedBox(height: 20),
            ReportCard(
              date: '22 Nov 2024',
              title: 'Monthly Routine Checkup with Dr. Robert Dunn',
              analysis: 'Heart Sound Analysis',
              score: 'Normal',
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Chat with AI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Chatbot', style: TextStyle(fontSize: 14)),
                  Text('Get lifestyle advice and information',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Ask me anything about your health and lifestyle!',
                      style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat History', style: TextStyle(fontSize: 14)),
                  Text('Previous Conversations',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('You: How can I improve my heart health?',
                      style: TextStyle(fontSize: 14)),
                  Text(
                      'AI: Regular exercise, a balanced diet, and regular checkups are key.',
                      style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
