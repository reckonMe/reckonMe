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

#include <iostream>
#include <vector>
#include <list>
#include <cmath>
#include <assert.h>
#include "matlab-utils.h"

using namespace std;


vector<double> filter(const vector<double> &a, const vector<double> &b, const vector<double> &x) {

  	// it probably makes sense to re-write this method using hardware-accelerated vDSP_convD()

    vector<double> y(x.size());
    
    size_t i, j;
	y[0] = b[0] * x[0];
	for (i = 1; i < b.size(); i++) {
        y[i] = 0.0;
        for (j = 0; j < i+1; j++)
        	y[i] += b[j] * x[i-j];
        for (j = 0; j < i; j++)
        	y[i] -= a[j+1] * y[i-j-1];
	}

	for (i = b.size(); i < x.size(); i++) {
		y[i] = 0.0;
        for (j = 0; j < b.size(); j++)
	        y[i] += b[j] * x[i-j];
	    for (j = 0; j < b.size()-1; j++)
	        y[i] -= a[j+1] * y[i-j-1];
	}
    
    return y;
}


vector<double> filtfilt (const vector<double> &a, const vector<double> &b, const vector<double> &x) {
    
    size_t border_size = 3*a.size();

	assert(a.size() == b.size() && x.size() > 2*border_size);

    // Reduce boundary effect - grow the signal with its inverted replicas on both edges
    vector<double> xx(x.size() + 2*border_size);
    
    for (int i=0; i < border_size; i++) {
        xx[i] = 2*x[0] - x[border_size-i-1];
        xx[xx.size()-i-1] = 2*x.back() - x[x.size()-border_size+i];
    }
    for (int i=0; i < x.size(); i++)
        xx[i+border_size] = x[i];
    
    // one-way filter
    vector<double> firstPass = filter(a, b, xx); 
    
    // reverse the series
    vector<double> rev(firstPass.rbegin(), firstPass.rend());
    
    // filter again
    vector<double> secondPass = filter(a, b, rev);
    
    // return a stripped series, reversed back
    return vector<double> (secondPass.rbegin() + border_size, secondPass.rend() - border_size);
}


vector<PeakEntry> peakdet(const vector<double> &data, size_t leftIdx, size_t rightIdx, double threshold) {
        
    vector<PeakEntry> peak_indices;
    
    double mx = -HUGE_VALF;
    double mn = HUGE_VALF;
    bool look_for_max = true;
    size_t mx_pos = 0;
    size_t mn_pos = 0;
    
    for (size_t i = leftIdx; i < rightIdx; i++) {
        double act = data[i];
        if (act > mx) {
            mx = act;
            mx_pos = i;
        }
        if (act < mn) {
            mn = act;
            mn_pos = i;
        }
        if (look_for_max) {
            if (act < mx - threshold) {
                peak_indices.push_back(PeakEntry(mx_pos, PeakEntry::up));
                mn = act;
                mn_pos = i;
                look_for_max = false;
            }
        }
        else if (act > mn + threshold) {
            peak_indices.push_back(PeakEntry(mn_pos, PeakEntry::down));
            mx = act;
            mx_pos = i;
            look_for_max = true;
        }            
    }
    
    return peak_indices;
}

