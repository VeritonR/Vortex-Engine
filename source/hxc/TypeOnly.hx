package hxc;

/**
 * What a script gets for importing something that's only a type (a typedef of a structure: V-Slice's `SongMetadata`, `StageData`...).
 * Scripts only name types with those, which they don't check: there's nothing to do with one, and the import isn't a missing one.
 */
@:keep
class TypeOnly {}
