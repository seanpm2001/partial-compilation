%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
% This file is part of openLilyLib,                                           %
%                      ===========                                            %
% the community library project for GNU LilyPond                              %
% (https://github.com/openlilylib)                                            %
%              -----------                                                    %
%                                                                             %
% Package: partial-compilation                                                %
%          ===================                                                %
%                                                                             %
% openLilyLib is free software: you can redistribute it and/or modify         %
% it under the terms of the GNU General Public License as published by        %
% the Free Software Foundation, either version 3 of the License, or           %
% (at your option) any later version.                                         %
%                                                                             %
% openLilyLib is distributed in the hope that it will be useful,              %
% but WITHOUT ANY WARRANTY; without even the implied warranty of              %
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               %
% GNU General Public License for more details.                                %
%                                                                             %
% You should have received a copy of the GNU General Public License           %
% along with openLilyLib. If not, see <http://www.gnu.org/licenses/>.         %
%                                                                             %
% openLilyLib is maintained by Urs Liska, ul@openlilylib.org                  %
% and others.                                                                 %
%       Copyright Urs Liska, 2016                                             %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% TODO: This may be changed to use lyp
\include "oll-core.ily"

\registerPackage partial-compilation

% require breaks functionality
% TODO: Change to lyp
\include "../breaks/package.ly"
% Define variables holding the conditional breaks.
% They expect lists with breaks. Each break can be
% - an integer representing the bar number
% - a list with a barnumber and a fraction
\registerOption comptools.line-breaks #'()
\registerOption comptools.page-breaks #'()
\registerOption comptools.page-turns #'()

% This functionality relies on the edition-engraver
% which is also part of openLilyLib
\include "editorial-tools/edition-engraver/definitions.ily"
\addEdition clips

% Initialize general clipping variables
#(define do-clip-region #f)
#(define clip-region-from 1)
#(define clip-region-to 1)

% Define (and activate) a clipping range.
% Only this range is typeset and compiled.
% Expect warnings about incomplete ties, dynamics etc. or other warnings/errors.
% If one of the arguments is out of range it is simply ignored
% (if #to is greater than the number of measures in the score
%  the score is engraved to the end).
setClipRegion =
#(define-void-function (parser location from to)
   (memom? memom?)
   (let ((clip-region-from
          (if (integer? from)
              (list from #{ 0/4 #})
              (list (car from)
                (ly:make-moment (numerator (cadr from))(denominator (cadr from))))))
         (clip-region-to
          (if (integer? to)
              (list (+ 1 to) #{ 0/4 #})
              (list (car to)
                (ly:make-moment (numerator (cadr to))(denominator (cadr to)))))))
   #{
     \editionMod clips 1 0/4 clip-regions.Score.A
     \set Score.skipTypesetting = ##t
     \editionMod clips #(car clip-region-from) #(cadr clip-region-from) clip-regions.Score.A
     \set Score.skipTypesetting = ##f
     \editionMod clips #(car clip-region-to) #(cadr clip-region-to) clip-regions.Score.A
     \set Score.skipTypesetting = ##t
   #}))

% define (and activate) a page range to be compiled alone.
% Pass first and last page as integers.
% Several validity checks are performed.
setClipPageRange =
#(define-void-function (parser location from to)
   (integer? integer?)
   (let* ((page-breaks #{ \getOption comptools.page-breaks #})
         (page-count (length page-breaks)))
   (if (= 0 page-count)
       (oll:warn "\\setClipPageRange requested, but no original page breaks defined. 
Continuing by compiling the whole score.~a""")
       ;; We do have page breaks so continue by retrieving barnumbers from that list
       (cond
        ((> from to)
         (oll:warn "\\setClipPageRange: Negative page range requested. 
Continuing by compiling the whole score.~a" ""))
        ((< from 1)
         (oll:warn "\\setClipPageRange: Page number below 1 requested. 
Continuing by compiling the whole score.~a" ""))
        ((> to (+ 1 page-count))
         (oll:warn "\\setClipPageRange: Page index out of range (~a). 
Continuing by compiling the whole score."
         (format "from ~a to ~a requested, ~a available" from to page-count)))
        (else
         (let ((from-bar (if (eq? from 1)
                             ;; First page is not included in the originalPageBreaks list
                             ;; so we set the barnumber to 1
                             1
                             (list-ref page-breaks (- from 2))))
               (to-bar (if (eq? to (+ (length page-breaks) 1))
                           ;; There is no page break *after* the last page,
                           ;; so we just set the "to" barnumber to -1
                           ;; because this simply discards the argument and compiles through to the end
                           -1
                           ;; Otherwise we look up the barnumber for the page break and subtract 1
                           ;; (the last measure to be included is the last one from the previous page
                           (- (list-ref page-breaks (- to 1)) 1))))
           #{ \setClipRegion #from-bar #to-bar #}))))))

% Define (and activate) a page to be compiled alone.
% Only that page is typeset
setClipPage =
#(define-void-function (parser location page)
   (integer?)
   #{ \setClipPageRange #page #page #})

\layout {
  \context {
    \Score
    \consists \editionEngraver clip-regions
  }
}
