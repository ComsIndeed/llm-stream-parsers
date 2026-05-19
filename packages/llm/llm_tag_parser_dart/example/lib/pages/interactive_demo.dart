import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InteractiveDemoPage extends StatelessWidget {
  const InteractiveDemoPage({super.key});

  final String _sampleText = 
      "Hello! I can definitely help you visualize quantum computing.\n"
      "<thinking>\n"
      "The user wants to see an interactive dashboard of quantum qubits.\n"
      "I should explain the basic concepts of superpositions.\n"
      "I'll stream conversational explanations, and enclose the dashboard in an interactive block.\n"
      "Let's set: id=\"quantum-dashboard\", layout=\"grid\", theme=\"dark\".\n"
      "</thinking>\n"
      "Quantum computing uses qubits instead of classical bits. While a classical bit is strictly 0 or 1, a qubit can exist in a superposition of both states until it is measured. Here is a live simulation:\n\n"
      "<interface id=\"quantum-dashboard\" layout=\"grid\" theme=\"dark\">\n"
      "Qubit #1: Superposition |ψ⟩ = 1/√2(|0⟩ + |1⟩)\n"
      "Probability State |0⟩: 50.0%\n"
      "Probability State |1⟩: 50.0%\n"
      "Coherence: 99.8%\n"
      "Entanglement Pair: Qubit #2\n"
      "</interface>\n\n"
      "As you can see from the interactive widget above, the probability states are equally distributed before collapse. Let me know if you would like to run another measurement operation!";

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.grey[950] : Colors.grey[50],
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LLM SOURCE TEXT REFERENCE',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111118) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[900]! : Colors.grey[200]!,
                  width: 1.5,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  _sampleText,
                  style: GoogleFonts.robotoMono(
                    color: isDark ? Colors.lightGreenAccent.shade100 : Colors.black87,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Stream<String> streamTextInChunks({
  required String text,
  required int chunkSize,
  required Duration interval,
  required bool Function() isPaused,
  required bool Function() isCancelled,
}) async* {
  final totalLength = text.length;
  var i = 0;
  while (i < totalLength) {
    if (isCancelled()) {
      break;
    }
    if (isPaused()) {
      await Future.delayed(const Duration(milliseconds: 50));
      continue;
    }
    
    final end = (i + chunkSize < totalLength) ? i + chunkSize : totalLength;
    yield text.substring(i, end);
    i = end;
    
    await Future.delayed(interval);
  }
}

