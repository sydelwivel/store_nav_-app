import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:collection';

// --- CORE PATHFINDING MODELS ---
class GraphNode {
  final String id;
  final int x;
  final int y;
  final double crowdFactor; // 1.0 (normal) to 5.0 (high crowd penalty)
  GraphNode(this.id, this.x, this.y, {this.crowdFactor = 1.0});
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GraphNode &&
              runtimeType == other.runtimeType &&
              id == other.id;
  @override
  int get hashCode => id.hashCode;
}

class PriorityQueue<T> {
  final List<T> _heap = [];
  final Comparator<T> _comparator;

  PriorityQueue(this._comparator);

  bool get isEmpty => _heap.isEmpty;
  bool get isNotEmpty => !isEmpty;

  void add(T element) {
    _heap.add(element);
    _heapifyUp(_heap.length - 1);
  }

  T removeMin() {
    if (isEmpty) throw StateError("PriorityQueue is empty");
    if (_heap.length == 1) return _heap.removeLast();
    final T min = _heap[0];
    _heap[0] = _heap.removeLast();
    _heapifyDown(0);
    return min;
  }

  void _heapifyUp(int index) {
    while (index > 0) {
      int parent = (index - 1) ~/ 2;
      if (_comparator(_heap[index], _heap[parent]) < 0) {
        _swap(index, parent);
        index = parent;
      } else {
        break;
      }
    }
  }

  void _heapifyDown(int index) {
    int left = 2 * index + 1;
    int right = 2 * index + 2;
    int smallest = index;
    if (left < _heap.length && _comparator(_heap[left], _heap[smallest]) < 0) {
      smallest = left;
    }
    if (right < _heap.length && _comparator(_heap[right], _heap[smallest]) < 0) {
      smallest = right;
    }
    if (smallest != index) {
      _swap(index, smallest);
      _heapifyDown(smallest);
    }
  }

  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }
}

// --- STORE MODELS ---
class StoreLocation {
  final String category;
  final String name;
  final int x;
  final int y;
  final Color color;
  StoreLocation({
    required this.category,
    required this.name,
    required this.x,
    required this.y,
    required this.color,
  });
}

class AisleZone {
  final String name;
  final Color color;
  final int startX;
  final int endX;
  final int startY;
  final int endY;
  final bool isCrowded;
  AisleZone({
    required this.name,
    required this.color,
    required this.startX,
    required this.endX,
    required this.startY,
    required this.endY,
    this.isCrowded = false,
  });
}

// --- DATA ---
const int MAP_WIDTH_UNITS = 60;
const int MAP_HEIGHT_UNITS = 30;
const double CROWD_PENALTY_FACTOR = 5.0;

final List<AisleZone> aisleZones = [
  AisleZone(
      name: 'Produce',
      color: const Color(0xFF4CAF50).withOpacity(0.4),
      startX: 2,
      endX: 12,
      startY: 2,
      endY: 24),
  AisleZone(
      name: 'Bakery',
      color: const Color(0xFFFF9800).withOpacity(0.4),
      startX: 13,
      endX: 26,
      startY: 1,
      endY: 8),
  AisleZone(
      name: 'Beverages',
      color: const Color(0xFF2196F3).withOpacity(0.4),
      startX: 13,
      endX: 26,
      startY: 9,
      endY: 30),
  AisleZone(
      name: 'Snacks/Sweets',
      color: const Color(0xFFFFEB3B).withOpacity(0.4),
      startX: 17,
      endX: 25,
      startY: 9,
      endY: 30),
  AisleZone(
      name: 'Pantry',
      color: const Color(0xFF795548).withOpacity(0.4),
      startX: 26,
      endX: 37,
      startY: 9,
      endY: 30),
  AisleZone(
      name: 'Household',
      color: const Color(0xFF9C27B0).withOpacity(0.4),
      startX: 37,
      endX: 43,
      startY: 9,
      endY: 30),
  AisleZone(
      name: 'Frozen',
      color: const Color(0xFF00BCD4).withOpacity(0.4),
      startX: 44,
      endX: 50,
      startY: 9,
      endY: 30),
  AisleZone(
      name: 'Dairy & Cheese',
      color: const Color(0xFFB0BEC5).withOpacity(0.4),
      startX: 51,
      endX: 58,
      startY: 9,
      endY: 30),
  AisleZone(
      name: 'Meat/Seafood',
      color: const Color(0xFFF44336).withOpacity(0.4),
      startX: 27,
      endX: 40,
      startY: 2,
      endY: 8),
  AisleZone(
      name: 'Entrance/Exit',
      color: const Color(0xFFFF0000).withOpacity(0.2),
      startX: 5,
      endX: 20,
      startY: 28,
      endY: 30,
      isCrowded: true),
  AisleZone(
      name: 'Checkout Lanes',
      color: const Color(0xFFFF0000).withOpacity(0.2),
      startX: 40,
      endX: 58,
      startY: 28,
      endY: 30,
      isCrowded: true),
  AisleZone(
      name: 'Deli/Meat Line',
      color: const Color(0xFFFF0000).withOpacity(0.2),
      startX: 30,
      endX: 36,
      startY: 1,
      endY: 3,
      isCrowded: true),
];

final List<StoreLocation> allProducts = [
  StoreLocation(category: 'Fruits & Vegetable', name: 'Apples', x: 4, y: 3, color: Colors.green),
  StoreLocation(category: 'Fruits & Vegetable', name: 'Tomato', x: 6, y: 5, color: Colors.green),
  StoreLocation(category: 'Bakery', name: 'White Bread', x: 14, y: 3, color: Colors.orange),
  StoreLocation(category: 'Bakery', name: 'Bagels', x: 15, y: 3, color: Colors.orange),
  StoreLocation(category: 'Snacks & Sweets', name: 'Potato Chips', x: 18, y: 10, color: Colors.yellow.shade800),
  StoreLocation(category: 'Snacks & Sweets', name: 'Chocolate Bar', x: 18, y: 15, color: Colors.yellow.shade800),
  StoreLocation(category: 'Beverages', name: 'Cola 2L', x: 14, y: 10, color: Colors.blue),
  StoreLocation(category: 'Beverages', name: 'Water', x: 16, y: 20, color: Colors.blue),
  StoreLocation(category: 'Pantry', name: 'Spaghetti', x: 26, y: 10, color: Colors.brown),
  StoreLocation(category: 'Pantry', name: 'Flour', x: 28, y: 29, color: Colors.brown),
  StoreLocation(category: 'Meat & Seafood', name: 'Chicken Breast', x: 28, y: 3, color: Colors.red),
  StoreLocation(category: 'Meat & Seafood', name: 'Salmon', x: 28, y: 5, color: Colors.red),
  StoreLocation(category: 'Household', name: 'Paper Towels', x: 38, y: 10, color: Colors.purple),
  StoreLocation(category: 'Household', name: 'Laundry Detergent', x: 38, y: 15, color: Colors.purple),
  StoreLocation(category: 'Frozen', name: 'Frozen Peas', x: 42, y: 10, color: Colors.cyan),
  StoreLocation(category: 'Frozen', name: 'Ice Cream', x: 47, y: 10, color: Colors.cyan),
  StoreLocation(category: 'Dairy & Cheese', name: 'Whole Milk', x: 57, y: 10, color: Colors.white),
  StoreLocation(category: 'Dairy & Cheese', name: 'Cheddar Block', x: 57, y: 13, color: Colors.white),
];

// --- GRAPH GENERATION ---
Map<GraphNode, Map<GraphNode, double>> buildGraph() {
  final graph = <GraphNode, Map<GraphNode, double>>{};

  final List<GraphNode> nodes = [];

  for (var p in allProducts) {
    nodes.add(GraphNode(p.name, p.x, p.y));
  }

  final List<Offset> junctions = [
    const Offset(10, 29),
    const Offset(45, 29),
    const Offset(10, 25),
    const Offset(20, 25),
    const Offset(35, 25),
    const Offset(50, 25),
    const Offset(10, 10),
    const Offset(20, 10),
    const Offset(35, 10),
    const Offset(50, 10),
    const Offset(20, 7),
    const Offset(35, 7),
    const Offset(50, 7),
  ];

  for (int i = 0; i < junctions.length; i++) {
    double crowd = getCrowdFactor(junctions[i].dx.toInt(), junctions[i].dy.toInt());
    nodes.add(GraphNode('Junction_$i', junctions[i].dx.toInt(), junctions[i].dy.toInt(), crowdFactor: crowd));
  }

  for (var node in nodes) {
    graph[node] = {};
  }

  for (var nodeA in nodes) {
    final distances = <GraphNode, double>{};
    for (var nodeB in nodes) {
      if (nodeA != nodeB) {
        distances[nodeB] = calculateDistance(nodeA, nodeB);
      }
    }
    final sortedNeighbors = distances.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (int i = 0; i < min(3, sortedNeighbors.length); i++) {
      final neighbor = sortedNeighbors[i].key;
      final distance = sortedNeighbors[i].value;
      graph[nodeA]![neighbor] = distance;
      graph[neighbor]![nodeA] = distance;
    }
  }
  return graph;
}

// --- UTILITIES ---
double calculateDistance(GraphNode a, GraphNode b) {
  return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
}

double getCrowdFactor(int x, int y) {
  for (var zone in aisleZones) {
    if (zone.isCrowded && x >= zone.startX && x <= zone.endX && y >= zone.startY && y <= zone.endY) {
      return CROWD_PENALTY_FACTOR;
    }
  }
  return 1.0;
}

List<Offset> reconstructPath(Map<GraphNode, GraphNode?> predecessors, GraphNode endNode) {
  final List<Offset> path = [];
  GraphNode? current = endNode;
  while (current != null) {
    path.add(Offset(current.x.toDouble(), current.y.toDouble()));
    current = predecessors[current];
  }
  return path.reversed.toList();
}

// --- PATHFINDING ALGORITHMS ---

({List<Offset> path, double distance}) dijkstra(
    Map<GraphNode, Map<GraphNode, double>> graph,
    GraphNode startNode,
    GraphNode endNode,
    ) {
  final distances = <GraphNode, double>{};
  final predecessors = <GraphNode, GraphNode?>{};
  final pq = PriorityQueue<GraphNode>((a, b) => distances[a]!.compareTo(distances[b]!));

  for (var node in graph.keys) {
    distances[node] = double.infinity;
    predecessors[node] = null;
  }

  distances[startNode] = 0.0;
  pq.add(startNode);

  while (pq.isNotEmpty) {
    GraphNode current = pq.removeMin();
    if (current == endNode) break;

    for (var neighborEntry in graph[current]!.entries) {
      GraphNode neighbor = neighborEntry.key;
      double edgeWeight = neighborEntry.value;
      double newDist = distances[current]! + edgeWeight;
      if (newDist < distances[neighbor]!) {
        distances[neighbor] = newDist;
        predecessors[neighbor] = current;
        pq.add(neighbor);
      }
    }
  }
  final path = reconstructPath(predecessors, endNode);
  final distance = distances[endNode] ?? double.infinity;
  return (path: path, distance: distance);
}

({List<Offset> path, double distance}) aStar(
    Map<GraphNode, Map<GraphNode, double>> graph,
    GraphNode startNode,
    GraphNode endNode, {
      bool useCrowd = false,
    }) {
  final gScores = <GraphNode, double>{};
  final fScores = <GraphNode, double>{};
  final predecessors = <GraphNode, GraphNode?>{};
  final pq = PriorityQueue<GraphNode>((a, b) => fScores[a]!.compareTo(fScores[b]!));

  double heuristic(GraphNode node) => calculateDistance(node, endNode);

  for (var node in graph.keys) {
    gScores[node] = double.infinity;
    fScores[node] = double.infinity;
    predecessors[node] = null;
  }

  gScores[startNode] = 0.0;
  fScores[startNode] = heuristic(startNode);
  pq.add(startNode);

  while (pq.isNotEmpty) {
    GraphNode current = pq.removeMin();
    if (current == endNode) break;

    for (var neighborEntry in graph[current]!.entries) {
      GraphNode neighbor = neighborEntry.key;
      double baseDistance = neighborEntry.value;
      double edgeWeight = baseDistance;
      if (useCrowd) {
        edgeWeight += CROWD_PENALTY_FACTOR * neighbor.crowdFactor;
      }
      double newGScore = gScores[current]! + edgeWeight;
      if (newGScore < gScores[neighbor]!) {
        gScores[neighbor] = newGScore;
        predecessors[neighbor] = current;
        fScores[neighbor] = newGScore + heuristic(neighbor);
        pq.add(neighbor);
      }
    }
  }
  final path = reconstructPath(predecessors, endNode);
  final distance = gScores[endNode] ?? double.infinity;
  return (path: path, distance: distance);
}

({List<Offset> path, double distance}) aStarCrowdOptimized(
    Map<GraphNode, Map<GraphNode, double>> graph,
    GraphNode startNode,
    GraphNode endNode,
    ) {
  return aStar(graph, startNode, endNode, useCrowd: true);
}

bool lineOfSight(GraphNode a, GraphNode b, Map<GraphNode, Map<GraphNode, double>> graph) {
  return graph[a]!.containsKey(b);
}

({List<Offset> path, double distance}) thetaStar(
    Map<GraphNode, Map<GraphNode, double>> graph,
    GraphNode startNode,
    GraphNode endNode, {
      bool useCrowd = false,
    }) {
  final gScores = <GraphNode, double>{};
  final fScores = <GraphNode, double>{};
  final predecessors = <GraphNode, GraphNode?>{};
  final openSet = PriorityQueue<GraphNode>((a, b) => fScores[a]!.compareTo(fScores[b]!));

  double heuristic(GraphNode node) => calculateDistance(node, endNode);

  for (var node in graph.keys) {
    gScores[node] = double.infinity;
    fScores[node] = double.infinity;
    predecessors[node] = null;
  }

  gScores[startNode] = 0.0;
  fScores[startNode] = heuristic(startNode);
  openSet.add(startNode);

  while (openSet.isNotEmpty) {
    GraphNode current = openSet.removeMin();
    if (current == endNode) break;

    for (var neighborEntry in graph[current]!.entries) {
      GraphNode neighbor = neighborEntry.key;
      double baseDistance = neighborEntry.value;
      double edgeWeight = baseDistance;
      if (useCrowd) {
        edgeWeight += CROWD_PENALTY_FACTOR * neighbor.crowdFactor;
      }
      GraphNode? parent = predecessors[current];
      if (parent != null && lineOfSight(parent, neighbor, graph)) {
        double newGScore = gScores[parent]! + calculateDistance(parent, neighbor);
        if (newGScore < gScores[neighbor]!) {
          gScores[neighbor] = newGScore;
          predecessors[neighbor] = parent;
          fScores[neighbor] = newGScore + heuristic(neighbor);
          openSet.add(neighbor);
        }
      } else {
        double newGScore = gScores[current]! + edgeWeight;
        if (newGScore < gScores[neighbor]!) {
          gScores[neighbor] = newGScore;
          predecessors[neighbor] = current;
          fScores[neighbor] = newGScore + heuristic(neighbor);
          openSet.add(neighbor);
        }
      }
    }
  }
  final path = reconstructPath(predecessors, endNode);
  final distance = gScores[endNode] ?? double.infinity;
  return (path: path, distance: distance);
}

({List<Offset> path, double distance}) caTheta(
    Map<GraphNode, Map<GraphNode, double>> graph,
    GraphNode startNode,
    GraphNode endNode,
    ) {
  return thetaStar(graph, startNode, endNode, useCrowd: true);
}

// --- CUSTOM PAINTER ---
class StoreMapPainter extends CustomPainter {
  final List<AisleZone> zones;
  final List<StoreLocation> products;
  final List<StoreLocation> shoppingListItems;
  final List<Offset> path;
  final double scaleFactor;

  StoreMapPainter({
    required this.zones,
    required this.products,
    required this.shoppingListItems,
    required this.path,
    required this.scaleFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double unitWidth = size.width / MAP_WIDTH_UNITS;
    final double unitHeight = size.height / MAP_HEIGHT_UNITS;

    Offset toCanvas(int x, int y) => Offset(x * unitWidth, y * unitHeight);

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i <= MAP_WIDTH_UNITS; i++) {
      canvas.drawLine(Offset(i * unitWidth, 0), Offset(i * unitWidth, size.height), gridPaint);
    }
    for (int i = 0; i <= MAP_HEIGHT_UNITS; i++) {
      canvas.drawLine(Offset(0, i * unitHeight), Offset(size.width, i * unitHeight), gridPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var zone in zones) {
      final rect = Rect.fromPoints(toCanvas(zone.startX, zone.startY), toCanvas(zone.endX, zone.endY));
      final zonePaint = Paint()
        ..color = zone.color
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, zonePaint);

      double fontSize = 10 * scaleFactor;
      double textYOffset = 0;

      if (zone.name == 'Beverages' || zone.name == 'Snacks/Sweets') {
        fontSize = 8 * scaleFactor;
        if (zone.name == 'Beverages') textYOffset = -fontSize;
        if (zone.name == 'Snacks/Sweets') textYOffset = fontSize;
      }

      final textSpan = TextSpan(
          text: zone.name,
          style: TextStyle(
            color: Colors.black.withOpacity(0.8),
            fontSize: fontSize,
            fontWeight: zone.isCrowded ? FontWeight.bold : FontWeight.normal,
          ));
      textPainter.text = textSpan;
      textPainter.layout();

      final textX = rect.left + (rect.width / 2) - (textPainter.width / 2);
      final textY = rect.top + (rect.height / 2) - (textPainter.height / 2) + textYOffset;

      textPainter.paint(canvas, Offset(textX, textY));

      if (zone.isCrowded) {
        final crowdBorder = Paint()
          ..color = Colors.red.shade900
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * scaleFactor;
        canvas.drawRect(rect, crowdBorder);
      }
    }

    final productRadius = 4.0 * scaleFactor;
    for (var product in products) {
      final center = toCanvas(product.x, product.y);
      final productPaint = Paint()
        ..color = product.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, productRadius, productPaint);

      if (shoppingListItems.any((item) => item.name == product.name)) {
        final highlightPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * scaleFactor;
        canvas.drawCircle(center, productRadius + 1, highlightPaint);
      }
    }

    if (path.isNotEmpty) {
      final pathPaint = Paint()
        ..color = Colors.green.shade700
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0 * scaleFactor; // Reduced width

      final pathSegments = <Offset>[];
      for (var p in path) {
        pathSegments.add(toCanvas(p.dx.toInt(), p.dy.toInt()));
      }
      for (int i = 0; i < pathSegments.length - 1; i++) {
        canvas.drawLine(pathSegments[i], pathSegments[i + 1], pathPaint);
      }

      if (pathSegments.isNotEmpty) {
        canvas.drawCircle(pathSegments.first, productRadius * 2, Paint()..color = Colors.green.shade700);
        canvas.drawCircle(pathSegments.last, productRadius * 2, Paint()..color = Colors.red.shade700);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StoreMapPainter oldDelegate) {
    return oldDelegate.zones != zones ||
        oldDelegate.products != products ||
        oldDelegate.path != path ||
        oldDelegate.shoppingListItems != shoppingListItems;
  }
}

// --- MAIN APP ---
class StoreNavigationApp extends StatefulWidget {
  const StoreNavigationApp({super.key});
  @override
  State<StoreNavigationApp> createState() => _StoreNavigationAppState();
}

class _StoreNavigationAppState extends State<StoreNavigationApp> {
  List<StoreLocation> _shoppingList = [];
  List<Offset> _currentPath = [];
  String _selectedAlgorithm = 'A* Search (Crowd Optimized)';
  double _currentPathDistance = 0.0;
  late final Map<GraphNode, Map<GraphNode, double>> _graph;
  late GraphNode _startNode;
  late List<GraphNode> _targetProductNodes;
  late GraphNode _exitNode;

  @override
  void initState() {
    super.initState();
    _graph = buildGraph();
    _exitNode = GraphNode('Exit', 45, 29);
    _shoppingList = [
      allProducts.firstWhere((p) => p.name == 'Apples'),
      allProducts.firstWhere((p) => p.name == 'Cola 2L'),
      allProducts.firstWhere((p) => p.name == 'Cheddar Block'),
    ];
    try {
      _startNode = _graph.keys.firstWhere((node) => node.x == 10 && node.y == 29);
    } catch (e) {
      _startNode = GraphNode('Start_Error_Fallback', 10, 29);
      print('Initialization Error: Could not find start node (Entrance: 10, 29) in graph. $e');
    }
    _targetProductNodes = _shoppingList.map((item) {
      try {
        return _graph.keys.firstWhere((node) => node.id == item.name && node.x == item.x && node.y == item.y);
      } catch (e) {
        print('Warning: Product ${item.name} not found as a GraphNode. $e');
        return GraphNode(item.name, item.x, item.y);
      }
    }).toList();
    try {
      GraphNode foundExitNode = _graph.keys.firstWhere((node) => node.id == 'Junction_1' && node.x == 45 && node.y == 29);
      _exitNode = foundExitNode;
    } catch (e) {
      print('Warning: Exit node not found as a Junction in graph. $e');
    }
  }

  void _calculateMultiStopPath() {
    List<Offset> fullPath = [];
    double totalDistance = 0.0;
    List<GraphNode> stopsToVisit = List.from(_targetProductNodes);
    GraphNode currentNode = _startNode;

    ({List<Offset> path, double distance}) Function(
    Map<GraphNode, Map<GraphNode, double>>, GraphNode, GraphNode)
    algo;

    switch (_selectedAlgorithm) {
      case 'Dijkstra\'s Algorithm (Shortest Distance)':
        algo = dijkstra;
        break;
      case 'A* Search (Heuristic Shortest Path)':
        algo = (graph, start, end) => aStar(graph, start, end, useCrowd: false);
        break;
      case 'A* Search (Crowd Optimized)':
        algo = (graph, start, end) => aStar(graph, start, end, useCrowd: true);
        break;
      case 'Theta* Search (Heuristic Shortest Path)':
        algo = (graph, start, end) => thetaStar(graph, start, end, useCrowd: false);
        break;
      case 'CA-Theta Search (Crowd Optimized)':
        algo = caTheta;
        break;
      default:
        return;
    }

    while (stopsToVisit.isNotEmpty) {
      GraphNode? nextStop;
      double minCost = double.infinity;

      for (var stop in stopsToVisit) {
        try {
          final result = algo(_graph, currentNode, stop);
          if (result.distance < minCost) {
            minCost = result.distance;
            nextStop = stop;
          }
        } catch (e) {
          print('Error during stop calculation to ${stop.id}: $e');
          continue;
        }
      }

      if (nextStop != null) {
        final result = algo(_graph, currentNode, nextStop);
        if (fullPath.isNotEmpty) {
          fullPath.addAll(result.path.skip(1));
        } else {
          fullPath.addAll(result.path);
        }
        totalDistance += result.distance;
        currentNode = nextStop;
        stopsToVisit.remove(nextStop);
      } else {
        print('Warning: Could not find path to any remaining stop.');
        break;
      }
    }

    if (currentNode.id != _exitNode.id) {
      final exitResult = algo(_graph, currentNode, _exitNode);
      fullPath.addAll(exitResult.path.skip(1));
      totalDistance += exitResult.distance;
    }

    setState(() {
      _currentPath = fullPath;
      _currentPathDistance = totalDistance;
    });

    final distanceType = (_selectedAlgorithm == 'A* Search (Crowd Optimized)' || _selectedAlgorithm == 'CA-Theta Search (Crowd Optimized)')
        ? 'Weighted Cost'
        : 'Distance';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Multi-stop route calculated using $_selectedAlgorithm. Total $distanceType: ${totalDistance.toStringAsFixed(2)}'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _calculatePath() {
    _calculateMultiStopPath();
  }

  @override
  Widget build(BuildContext context) {
    final distanceText = (_selectedAlgorithm == 'A* Search (Crowd Optimized)' || _selectedAlgorithm == 'CA-Theta Search (Crowd Optimized)')
        ? 'Total Weighted Cost: ${_currentPathDistance.toStringAsFixed(2)}'
        : 'Total Distance: ${_currentPathDistance.toStringAsFixed(2)} units';

    final double mapHeight = 450;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Navigation 2D Map'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: mapHeight * 2,
                height: mapHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double canvasWidth = constraints.maxWidth;
                    final double scaleFactor = canvasWidth / MAP_WIDTH_UNITS;

                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.lightBlue.shade50),
                          child: CustomPaint(
                            size: Size(canvasWidth, constraints.maxHeight),
                            painter: StoreMapPainter(
                              zones: aisleZones,
                              products: allProducts,
                              shoppingListItems: _shoppingList,
                              path: _currentPath,
                              scaleFactor: scaleFactor / 10,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, color: Colors.red, size: 16),
                                SizedBox(width: 4),
                                Text('Red Border = Crowded Zone (High Cost)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Calculated Full Shopping Route:',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _currentPath.isEmpty ? 'Run algorithm to calculate path.' : distanceText,
                    style: TextStyle(fontSize: 18, color: Colors.indigo.shade800, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Shopping List (${_shoppingList.length} Stops, ending at Exit):',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: _shoppingList
                        .map((item) => Chip(label: Text(item.name, style: const TextStyle(fontSize: 12)), backgroundColor: item.color.withOpacity(0.7)))
                        .toList(),
                  ),
                  const Divider(height: 30),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'Select Pathfinding Algorithm',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                    value: _selectedAlgorithm,
                    items: <String>[
                      'Dijkstra\'s Algorithm (Shortest Distance)',
                      'A* Search (Heuristic Shortest Path)',
                      'A* Search (Crowd Optimized)',
                      'Theta* Search (Heuristic Shortest Path)',
                      'CA-Theta Search (Crowd Optimized)',
                    ].map<DropdownMenuItem<String>>((value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAlgorithm = value!;
                        _currentPath = [];
                        _currentPathDistance = 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _calculatePath,
                    icon: const Icon(Icons.alt_route),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('Calculate Full Optimized Route', style: TextStyle(fontSize: 16)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Store Navigation',
      theme: ThemeData(primarySwatch: Colors.indigo, fontFamily: 'Inter', useMaterial3: true),
      home: const StoreNavigationApp(),
    );
  }
}
