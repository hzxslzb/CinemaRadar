import 'package:flutter/material.dart';

import '../data/maoyan_provider.dart';
import '../domain/models.dart';

class CinemaSearchDialog extends StatefulWidget {
  const CinemaSearchDialog({super.key, required this.provider});

  final CinemaDirectoryProvider provider;

  @override
  State<CinemaSearchDialog> createState() => _CinemaSearchDialogState();
}

class _CinemaSearchDialogState extends State<CinemaSearchDialog> {
  final searchController = TextEditingController();
  List<CityOption> cities = const <CityOption>[];
  List<DistrictOption> districts = const <DistrictOption>[];
  List<Cinema> cinemas = const <Cinema>[];
  CityOption? city;
  DistrictOption? district;
  Cinema? selectedCinema;
  bool loadingCities = true;
  bool loadingDistricts = false;
  bool loadingCinemas = false;
  String? error;

  List<Cinema> get visibleCinemas =>
      fuzzyFilterCinemas(cinemas, searchController.text);

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    _loadCities();
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() => selectedCinema = null);
  }

  @override
  Widget build(BuildContext context) {
    final dialogHeight = (MediaQuery.sizeOf(context).height * 0.72)
        .clamp(420.0, 620.0)
        .toDouble();
    return AlertDialog(
      title: const Text('搜索并切换影院'),
      content: SizedBox(
        width: 560,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OutlinedButton(
              onPressed: loadingCities || cities.isEmpty ? null : _pickCity,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.location_city_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loadingCities
                          ? '正在加载完整城市列表…'
                          : city == null
                              ? '搜索城市（名称或拼音）'
                              : '${city!.name} · 共 ${cities.length} 个可用城市',
                    ),
                  ),
                  const Icon(Icons.search_rounded),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DistrictOption>(
              key: ValueKey<int?>(district?.id),
              initialValue: district,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: loadingDistricts ? '正在加载行政区…' : '影院所在区',
                border: const OutlineInputBorder(),
              ),
              items: districts
                  .map((value) => DropdownMenuItem<DistrictOption>(
                        value: value,
                        child: Text('${value.name}（${value.cinemaCount} 家）'),
                      ))
                  .toList(),
              onChanged: loadingDistricts ? null : _selectDistrict,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              enabled: cinemas.isNotEmpty && !loadingCinemas,
              decoration: const InputDecoration(
                labelText: '模糊搜索影院',
                hintText: '例如 MOViE、万达、前滩或地址关键词',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    loadingCinemas
                        ? '后台一次查询本区影院；输入搜索不会产生额外请求…'
                        : district == null
                            ? '先选择城市和区，才会查询影院列表'
                            : '本区 ${cinemas.length} 家 · 匹配 ${visibleCinemas.length} 家',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (loadingCities || loadingDistricts || loadingCinemas)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (error != null) ...<Widget>[
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: cinemas.isEmpty
                  ? Center(
                      child: Icon(
                        district == null
                            ? Icons.map_outlined
                            : Icons.local_movies_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibleCinemas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cinema = visibleCinemas[index];
                        final selected = cinema.id == selectedCinema?.id;
                        return ListTile(
                          selected: selected,
                          selectedTileColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          leading: Icon(selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off),
                          title: Text(cinema.name),
                          subtitle: cinema.address.isEmpty
                              ? null
                              : Text(
                                  cinema.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => setState(() => selectedCinema = cinema),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: selectedCinema == null
              ? null
              : () => Navigator.pop(context, selectedCinema),
          child: const Text('切换并查询'),
        ),
      ],
    );
  }

  Future<void> _loadCities() async {
    try {
      final values = await widget.provider.fetchCities();
      if (!mounted) return;
      final initial = values.where((item) => item.id == 10).firstOrNull;
      setState(() {
        cities = values;
        loadingCities = false;
        city = initial;
      });
      if (initial != null) await _selectCity(initial);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loadingCities = false;
        error = '城市列表加载失败：$exception';
      });
    }
  }

  Future<void> _pickCity() async {
    final value = await showSearch<CityOption?>(
      context: context,
      delegate: _CitySearchDelegate(cities),
    );
    if (value != null) await _selectCity(value);
  }

  Future<void> _selectCity(CityOption value) async {
    searchController.clear();
    setState(() {
      city = value;
      district = null;
      districts = const <DistrictOption>[];
      cinemas = const <Cinema>[];
      selectedCinema = null;
      loadingDistricts = true;
      error = null;
    });
    try {
      final values = await widget.provider.fetchDistricts(value);
      if (!mounted || city?.id != value.id) return;
      setState(() {
        districts = values;
        loadingDistricts = false;
      });
    } catch (exception) {
      if (!mounted || city?.id != value.id) return;
      setState(() {
        loadingDistricts = false;
        error = '行政区加载失败：$exception';
      });
    }
  }

  void _selectDistrict(DistrictOption? value) {
    if (value == null || city == null) return;
    searchController.clear();
    setState(() {
      district = value;
      cinemas = const <Cinema>[];
      selectedCinema = null;
      loadingCinemas = true;
      error = null;
    });
    _loadCinemas(city!, value);
  }

  Future<void> _loadCinemas(
    CityOption selectedCity,
    DistrictOption selectedDistrict,
  ) async {
    try {
      final values = await widget.provider.fetchCinemas(
        city: selectedCity,
        district: selectedDistrict,
      );
      if (!mounted ||
          city?.id != selectedCity.id ||
          district?.id != selectedDistrict.id) {
        return;
      }
      setState(() {
        cinemas = values;
        loadingCinemas = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loadingCinemas = false;
        error = '影院列表加载失败：$exception';
      });
    }
  }
}

class _CitySearchDelegate extends SearchDelegate<CityOption?> {
  _CitySearchDelegate(this.cities);

  final List<CityOption> cities;

  @override
  String get searchFieldLabel => '输入城市名称或拼音';

  @override
  List<Widget>? buildActions(BuildContext context) => <Widget>[
        IconButton(
          tooltip: '清空',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: '返回',
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded),
      );

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    final needle = query.trim().toLowerCase();
    final matches = cities
        .where((city) => needle.isEmpty || city.searchText.contains(needle))
        .take(100)
        .toList();
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final city = matches[index];
        return ListTile(
          leading: const Icon(Icons.location_city_outlined),
          title: Text(city.name),
          subtitle: Text(city.pinyin),
          onTap: () => close(context, city),
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
