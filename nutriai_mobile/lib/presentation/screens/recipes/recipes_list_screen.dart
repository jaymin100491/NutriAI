import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/recipe_provider.dart';
import '../diet_plan/recipe_detail_screen.dart';

class RecipesListScreen extends ConsumerStatefulWidget {
  const RecipesListScreen({super.key});

  @override
  ConsumerState<RecipesListScreen> createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends ConsumerState<RecipesListScreen> {
  final _searchController = TextEditingController();
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(recipeNotifierProvider.notifier).loadRecipes();
      ref.read(recipeNotifierProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipeState = ref.watch(recipeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterBottomSheet();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (recipeState.filters.hasActiveFilters) _buildActiveFiltersChips(),
          Expanded(
            child: recipeState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : recipeState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              recipeState.error!,
                              style: const TextStyle(color: AppTheme.errorColor),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                ref.read(recipeNotifierProvider.notifier).loadRecipes();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : recipeState.filteredRecipes.isEmpty
                        ? const Center(child: Text('No recipes found'))
                        : _isGridView
                            ? _buildGridView(recipeState.filteredRecipes)
                            : _buildListView(recipeState.filteredRecipes),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search recipes...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(recipeNotifierProvider.notifier).setSearch(null);
                  },
                )
              : null,
        ),
        onChanged: (value) {
          ref.read(recipeNotifierProvider.notifier).setSearch(value.isEmpty ? null : value);
        },
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    final recipeState = ref.watch(recipeNotifierProvider);
    final filters = recipeState.filters;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (filters.cuisineType != null)
            _buildFilterChip(
              'Cuisine: ${filters.cuisineType}',
              () => ref.read(recipeNotifierProvider.notifier).setCuisineType(null),
            ),
          if (filters.mealType != null)
            _buildFilterChip(
              'Meal: ${filters.mealType}',
              () => ref.read(recipeNotifierProvider.notifier).setMealType(null),
            ),
          ...filters.dietaryTags.map((tag) => _buildFilterChip(
                tag,
                () => ref.read(recipeNotifierProvider.notifier).toggleDietaryTag(tag),
              )),
          if (filters.maxCalories != null)
            _buildFilterChip(
              'Max ${filters.maxCalories} cal',
              () => ref.read(recipeNotifierProvider.notifier).setMaxCalories(null),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              label: const Text('Clear All'),
              onPressed: () {
                _searchController.clear();
                ref.read(recipeNotifierProvider.notifier).clearFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        onDeleted: onDelete,
        deleteIcon: const Icon(Icons.close, size: 18),
      ),
    );
  }

  Widget _buildGridView(List<dynamic> recipes) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return _buildRecipeGridCard(recipes[index]);
      },
    );
  }

  Widget _buildListView(List<dynamic> recipes) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        return _buildRecipeListCard(recipes[index]);
      },
    );
  }

  Widget _buildRecipeGridCard(dynamic recipe) {
    final recipeState = ref.watch(recipeNotifierProvider);
    final isFavorite = recipeState.favoriteIds.contains(recipe.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                recipe.imageUrl.isNotEmpty
                    ? Image.network(
                        recipe.imageUrl,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            color: Colors.grey[200],
                            child: const Icon(Icons.restaurant, size: 48),
                          );
                        },
                      )
                    : Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(Icons.restaurant, size: 48),
                      ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 16,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey,
                        size: 18,
                      ),
                      onPressed: () {
                        ref.read(recipeNotifierProvider.notifier).toggleFavorite(recipe.id);
                      },
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: AppTheme.textSecondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.totalTimeMinutes} min',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.nutrition.calories} cal',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeListCard(dynamic recipe) {
    final recipeState = ref.watch(recipeNotifierProvider);
    final isFavorite = recipeState.favoriteIds.contains(recipe.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: recipe.imageUrl.isNotEmpty
                    ? Image.network(
                        recipe.imageUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.restaurant),
                          );
                        },
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.restaurant),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInfoBadge(Icons.access_time, '${recipe.totalTimeMinutes} min'),
                        const SizedBox(width: 12),
                        _buildInfoBadge(Icons.local_fire_department, '${recipe.nutrition.calories} cal'),
                        const SizedBox(width: 12),
                        _buildInfoBadge(Icons.signal_cellular_alt, recipe.difficulty),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                ),
                onPressed: () {
                  ref.read(recipeNotifierProvider.notifier).toggleFavorite(recipe.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _FilterSheet(scrollController: scrollController);
        },
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _FilterSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeState = ref.watch(recipeNotifierProvider);
    final filters = recipeState.filters;

    return Container(
      padding: const EdgeInsets.all(20),
      child: ListView(
        controller: scrollController,
        children: [
          const Text(
            'Filter Recipes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildCuisineFilter(ref, filters),
          const SizedBox(height: 24),
          _buildMealTypeFilter(ref, filters),
          const SizedBox(height: 24),
          _buildDietaryTagsFilter(ref, filters),
          const SizedBox(height: 24),
          _buildCaloriesFilter(ref, filters),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(recipeNotifierProvider.notifier).clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCuisineFilter(WidgetRef ref, RecipeFilters filters) {
    final cuisines = ['Italian', 'Chinese', 'Indian', 'Mexican', 'Japanese', 'Mediterranean'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cuisine Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cuisines.map((cuisine) {
            final isSelected = filters.cuisineType == cuisine;
            return FilterChip(
              label: Text(cuisine),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(recipeNotifierProvider.notifier).setCuisineType(selected ? cuisine : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMealTypeFilter(WidgetRef ref, RecipeFilters filters) {
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Meal Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: mealTypes.map((mealType) {
            final isSelected = filters.mealType == mealType;
            return FilterChip(
              label: Text(mealType),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(recipeNotifierProvider.notifier).setMealType(selected ? mealType : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDietaryTagsFilter(WidgetRef ref, RecipeFilters filters) {
    final tags = ['Vegetarian', 'Vegan', 'Gluten-Free', 'Dairy-Free', 'Keto', 'High-Protein'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dietary Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = filters.dietaryTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(recipeNotifierProvider.notifier).toggleDietaryTag(tag);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCaloriesFilter(WidgetRef ref, RecipeFilters filters) {
    final calorieOptions = [300, 500, 700, 1000];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Max Calories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: calorieOptions.map((calories) {
            final isSelected = filters.maxCalories == calories;
            return FilterChip(
              label: Text('$calories cal'),
              selected: isSelected,
              onSelected: (selected) {
                ref.read(recipeNotifierProvider.notifier).setMaxCalories(selected ? calories : null);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
