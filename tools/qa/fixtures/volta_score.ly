\version "2.24.4"
\paper {
  #(set-paper-size "a4")
  top-margin = 20\mm
  bottom-margin = 20\mm
}
\header {
  title = "Test OMR LilyPond"
  composer = "OpenCello QA"
}
\score {
  \new Staff \with { instrumentName = "Violoncelle" } {
    \clef bass
    \key c \major
    \time 4/4
    \repeat volta 2 {
      g,4 a, b, c |
      d4 e f g |
      <d f>2 g,2 |
      c1~ |
    }
    \alternative {
      { c4 r4 r2 }
      { <d f>1 }
    }
  }
  \layout { }
}
