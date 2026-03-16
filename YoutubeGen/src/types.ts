export interface TrendingTopic {
  topic: string;
  source: 'google' | 'reddit' | 'twitter' | 'manual';
  context: string;
  sentiment: 'positive' | 'negative' | 'neutral' | 'mixed';
  score: number;
}

export interface Caption {
  text: string;
  mood: string;
  format: string;
  confidence: number;
  topic: string;
  grokNotes?: string;
}

export interface SceneAlternative {
  movieTitle: string;
  year?: number;
  character: string;
  momentDescription: string;
  searchKeywords: string[];
}

export interface SceneMatch {
  movieTitle: string;
  year: number;
  character: string;
  momentDescription: string;
  emotionalMatch: string;
  searchKeywords: string[];
  clipStartHint: string;
  clipEndHint: string;
  emotion: string;
  confidence: number;
  alternatives: SceneAlternative[];
}

export interface CachedClip {
  id: string;
  filePath: string;
  sourceUrl: string;
  videoId: string;
  movieTitle: string;
  character: string;
  emotion: string;
  mood: string;
  durationSec: number;
  createdAt: string;
}

export interface ShortOutput {
  videoPath: string;
  thumbnailPath: string;
  metadataPath: string;
  caption: Caption;
  scene: SceneMatch;
}

export interface VideoMetadata {
  title: string;
  description: string;
  hashtags: string[];
  tags: string[];
  category: string;
  pinnedComment?: string;
  animalSpecies?: string;
}

export interface AnimalClipContext {
  /** The Cully Mode caption text, e.g. "he checks in with the hole" */
  captionText: string;
  /**
   * Specific animal species, e.g. "hyrax", "capuchin monkey", "cockatoo".
   * When unknown, use the generic noun ("bird", "cat") — but be specific if you can.
   */
  animalSpecies: string;
  /**
   * One-line behavior description for keyword generation, e.g. "screaming at nothing"
   */
  behavior: string;
}

export interface PipelineResult {
  topic: TrendingTopic;
  caption: Caption;
  scene: SceneMatch;
  clipPath: string;
  output: ShortOutput;
}

export type UploadStatus = 'pending' | 'uploaded' | 'unlisted' | 'public' | 'scheduled' | 'deleted' | 'failed';

export interface UploadRecord {
  outputName: string;
  videoId: string | null;
  youtubeUrl: string | null;
  status: UploadStatus;
  uploadedAt: string | null;
  publishedAt: string | null;
  metadataPath: string;
  videoPath: string;
  thumbnailPath: string;
  error?: string;
}
