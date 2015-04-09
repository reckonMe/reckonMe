/**
*	The BSD 2-Clause License (aka "FreeBSD License")
*
*	Copyright (c) 2012, Benjamin Thiel, Kamil Kloch
*	All rights reserved.
*
*	Redistribution and use in source and binary forms, with or without
*	modification, are permitted provided that the following conditions are met: 
*
*	1. Redistributions of source code must retain the above copyright notice, this
*	   list of conditions and the following disclaimer. 
*	2. Redistributions in binary form must reproduce the above copyright notice,
*	   this list of conditions and the following disclaimer in the documentation
*	   and/or other materials provided with the distribution. 
*
*	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
*	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
*	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
*	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
*	ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
*	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
*	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
*	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
*	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

#ifndef PDR_matlab_utils_h
#define PDR_matlab_utils_h

#include <vector>

using namespace std;

struct PeakEntry {
    enum PeakType { down = -1, undefined, up };
  
    PeakType peakType;
    size_t index;

    PeakEntry(size_t idx, PeakType pType) : index(idx), peakType(pType) {}
};


//  Matlab's 'filter' 
vector<double> filter(const vector<double> &a, const vector<double> &b, const vector<double> &x);

//  Matlab's 'filtfilt' with naive start-up and ending smoothing 
vector<double> filtfilt (const vector<double> &a, const vector<double> &b, const vector<double> &x);

// Detects local maxima. A point is considered a max peak if it has maximal value 
// and is preceded (to the left) by a value lower by 'threshold' 
vector<PeakEntry> peakdet(const vector<double> &data, size_t leftIdx, size_t rightIdx, double threshold);

#endif
