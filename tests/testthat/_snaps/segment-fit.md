# segmented documents carry their parent and position

    Code
      print(model)
    Output
      <sbert_topic_model>
        documents: 3 
        segments: 8 (sentence level) 
        topics: 2
        model: precomputed embeddings
        algorithm: deterministic k-means (Lloyd)
        topic sizes: 4, 4
        between/total SS: 99.6%

# topic_corpus records the segmentation and fits identically

    Code
      print(corpus)
    Output
      <sbert_topic_corpus>
        documents: 3 
        segments: 8 (sentence level) 
        embedding dimension: 2 
        model: precomputed embeddings 
        tokenization: min_token_length = 2  

# compare_topics compares several segment levels in one table

    Code
      print(levels)
    Output
      <sbert_topic_sweep> 2 candidates, coherence measure: npmi
        segment n_topics  coherence topic_diversity explained
       document        2  0.0000000               1 0.7491596
       sentence        2 -0.1934264               1 0.9954323
      
      Fitted models retained: fitted(x, n_topics = 2, segment = "document")

