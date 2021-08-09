part of yandex_mapkit;

class YandexSearch {

  static const String _channelName = 'yandex_mapkit/yandex_search';

  static const MethodChannel _channel = MethodChannel(_channelName);

  static int _nextCallbackId = 0;
  static final Map<int, SuggestSessionCallback> _suggestSessionsById = {};

  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSuggestListenerResponse':
        _onSuggestListenerResponse(call.arguments);
        break;
      case 'onSuggestListenerError':
        _onSuggestListenerError(call.arguments);
        break;
      case 'onSuggestListenerRemove':
        _onSuggestListenerRemove(call.arguments);
        break;

      case 'onSearchListenerResponse':
        _onSearchListenerResponse(call.arguments);
        break;
      case 'onSearchListenerError':
        _onSearchListenerError(call.arguments);
        break;


      default:
        throw MissingPluginException();
    }
  }

  static Future<CancelSuggestCallback> getSuggestions({
    required String address,
    required Point southWestPoint,
    required Point northEastPoint,
    required SuggestType suggestType,
    required bool suggestWords,
    required SuggestSessionCallback onSuggest
  }) async {
    _channel.setMethodCallHandler(_handleMethodCall);

    final listenerId = _nextCallbackId++;
    _suggestSessionsById[listenerId] = onSuggest;

    await _channel.invokeMethod<void>(
      'getSuggestions',
      <String, dynamic>{
        'formattedAddress': address,
        'southWestLatitude': southWestPoint.latitude,
        'southWestLongitude': southWestPoint.longitude,
        'northEastLatitude': northEastPoint.latitude,
        'northEastLongitude': northEastPoint.longitude,
        'suggestType': suggestType.index,
        'suggestWords': suggestWords,
        'listenerId': listenerId
      }
    );

    return () => _cancelSuggestSession(listenerId);
  }

  static void _onSuggestListenerRemove(dynamic arguments) {
    _cancelSuggestSession(arguments['listenerId']);
  }

  static Future<void> _cancelSuggestSession(int listenerId) async {
    if (_suggestSessionsById.containsKey(listenerId)) {
      _suggestSessionsById.remove(listenerId);
      await _channel.invokeMethod<void>(
        'cancelSuggestSession',
        <String, dynamic>{
          'listenerId': listenerId
        }
      );
    }
  }

  static void _onSuggestListenerResponse(dynamic arguments) {
    final List<dynamic> suggests = arguments['response'];
    final suggestItems = suggests.map((dynamic sug) {
      return SuggestItem(
        title: sug['title'],
        subtitle: sug['subtitle'],
        displayText: sug['displayText'],
        searchText: sug['searchText'],
        type: SuggestItemType.values[sug['type']],
        tags: sug['tags'],
      );
    }).toList();
    final int listenerId = arguments['listenerId'];

    _suggestSessionsById[listenerId]!(suggestItems);
    _cancelSuggestSession(listenerId);
  }

  static void _onSuggestListenerError(dynamic arguments) {
    _cancelSuggestSession(arguments['listenerId']);
  }

  static final Map<int, SearchSessionCallbackItems> _searchSessionsById = {};

  static Future<CancelSearchCallback> searchByText({
    required  String        searchText,
    required  Geometry      geometry,
    required  SearchOptions searchOptions,
    required  SearchSessionCallbackItems onResponseSearch
  }) async {

    _channel.setMethodCallHandler(_handleMethodCall);

    final listenerId = _nextCallbackId++;
    _searchSessionsById[listenerId] = onResponseSearch;

    var params = {
      'searchText': searchText,
      'geometry':   geometry.toJson(),
      'options':    searchOptions.toJson(),
      'listenerId': listenerId
    };

    await _channel.invokeMethod<void>(
      'searchByText',
      params
    );
    return () => _cancelSearchSession(listenerId);
    // return SearchSession(id: listenerId);
  }

  static Future<void> _cancelSearchSession(int listenerId) async {
    print('cancel search session');
    if (_searchSessionsById.containsKey(listenerId)) {
      _searchSessionsById.remove(listenerId);
      await _channel.invokeMethod<void>(
          'cancelSearchSession',
          <String, dynamic>{
            'listenerId': listenerId
          }
      );
    }
  }


  static void _onSearchListenerResponse(dynamic arguments) {
    final resultSearch = arguments['response']['items'];
    List<SearchItem> SearchItems = [];
    for (int i=0; i<resultSearch.length ; i++){
      List<Geometry> geometry = [];
      if(resultSearch[i]['geometry'].length > 1){
          for (int i=0; i<resultSearch[i]['geometry'].length ; i++){
            geometry.add(Geometry.fromJson(resultSearch[i]['geometry'][i]));
          }
      }else{
        geometry.add(Geometry.fromJson(resultSearch[i]['geometry'][0]));
      }
      var businessData;
      if(arguments['response']['items'][i]['businessMetadata'] != null){
        businessData = SearchItemBusinessMetadata.fromJson(arguments['response']['items'][i]['businessMetadata']);
      }else {
        businessData = null;
      }

      SearchItems.add(
          SearchItem(
          name: resultSearch[i]['name'],
          geometry: geometry,
          businessMetadata: businessData,
          toponymMetadata: SearchItemToponymMetadata.fromJson(arguments['response']['items'][i]['toponymMetadata'])
      ));
    }
    // print(SearchItems);
    // List<dynamic> SearchItems = resultSearch.map((dynamic item) {
    //   print('qwe');
    //   // return SearchItem(
    //   //     name: item['name'],
    //   //     geometry: [Geometry.fromJson(item['geometry'][0])],
    //   //     // businessMetadata: item['businessMetadata'] ,
    //   //     // toponymMetadata: item['toponymMetadata']
    //   // );
    // }
    //   );
    // // print(SearchItems);
    final int listenerId = arguments['listenerId'];
    _searchSessionsById[listenerId]!(SearchItems);
    _cancelSearchSession(listenerId);
  }

  static void _onSearchListenerError(dynamic arguments) {
    _cancelSearchSession(arguments['listenerId']);
  }
}
