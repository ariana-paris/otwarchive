module Import::ImportConstants
  # time out if we can't download fast enough
  STORY_DOWNLOAD_TIMEOUT = 60
  MAX_CHAPTER_COUNT = 200

  # To check for duplicate chapters, take a slice this long out of the story
  # (in characters)
  DUPLICATE_CHAPTER_LENGTH = 10_000
end