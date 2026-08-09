import 'package:flutter/material.dart';

import 'patients_screen.dart';
import 'medicines_screen.dart';
import 'treatments_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Tamaño adaptable del logo.
    final double logoSize = screenHeight < 500
        ? screenHeight * 0.35
        : screenWidth > 600
        ? 300
        : 360;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text("PETMEDS")),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  const SizedBox(height: 10),

                  // LOGO
                  Center(
                    child: Image.asset(
                      'assets/images/isologo_petmeds.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Center(
                    child: Text(
                      "PETMEDS",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Center(
                    child: Text(
                      "Medication Reminder",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // MASCOTAS
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PatientsScreen(),
                          ),
                        );
                      },
                      child: const Text("Mascotas"),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // MEDICAMENTOS
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MedicinesScreen(),
                          ),
                        );
                      },
                      child: const Text("Medicines"),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // TRATAMIENTOS
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TreatmentsScreen(),
                          ),
                        );
                      },
                      child: const Text("Treatments"),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
