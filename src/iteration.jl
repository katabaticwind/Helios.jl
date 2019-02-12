using Dates

abstract type Iterator end

mutable struct DateIterator
    dates::Array{Date,1}
    period::DatePeriod
end

mutable struct DateIndex
    index::Integer
    date::Date
end

import Base. copy
function copy(idx::DateIndex)
    return DateIndex(idx.index, idx.date)
end

# TODO: check for missing periods?
function shift!(idx::DateIndex, dates, period; firstindex = true)
    idx.date + period > dates[end] && return nothing
    idx.index == length(dates) && return nothing
    date = idx.date
    if firstindex
        while dates[idx.index] < idx.date + period
            idx.index += 1
        end
    else
        while dates[idx.index] <= idx.date + period
            idx.index += 1
            if idx.index > length(dates)
                break
            end
        end
        idx.index -= 1
    end
    idx.date = dates[idx.index]
    # idx.date != date + period && @warn("missing period encountered")
    return idx
end

function get_dateindex(date, dates)
    index = 1
    while dates[index] < date
        index += 1
    end
    return DateIndex(index, date)
end

import Base.iterate
# function iterate(iter::DateIterator)
#     length(iter.dates) == 0 && return nothing
#     state = DateIndex(1, iter.dates[1])
#     return iter.dates[1], shift!(state, iter.dates, iter.period)
# end
# function iterate(iter::DateIterator, state)
#     state = shift!(state, iter.dates, iter.period)
#     state == nothing && return nothing
#     return iter.dates[state.index], state
# end
function iterate(iter::DateIterator)
    length(iter.dates) == 0 && return nothing
    state = DateIndex(1, iter.dates[1])
    return 1, shift!(state, iter.dates, iter.period)
end
function iterate(iter::DateIterator, state)
    state = shift!(state, iter.dates, iter.period)
    state == nothing && return nothing
    return state.index, state
end

begindate = Date("2018-01-01")
enddate = Date("2018-02-01")
dates = begindate:Day(1):enddate
dates = sort(rand(dates, 100))
date_iterator = DateIterator(dates, Day(1))
idx = DateIndex(1, dates[1])
for index in date_iterator
    println(index)
end

"""
    Now we can iterate through data taking *time* steps of any period.

    # Example
    X = randn(100, 10)
    for index in date_iterator
        @show sum(X[i, :])
    end
"""

"""
    RollingWindow :< Iterator

    Given data `X` with corresponding dates `dates`, iterate through `X` by increasing the start date of `Xtrain`, `Xvalid`, and `Xtest` by a fixed `period`.

    # Arguments
    - `ntrain`: number of periods in each training sample.
    - `nvalid`: number of periods in each validation sample.
    - `ntest`: number of periods in each testing sample.
"""
function roll(X, iter::DateIterator, ntrain, nvalid, ntest)
    size(X, 1) != length(date_iterator.dates) && error("lengths don't match!")
    idx_train = get_dateindex(iter.dates[1], iter.dates)
    idx = find_endpoints(idx_train, ntrain, nvalid, ntest, dates, period)
    idx_train, idx_valid, idx_test, idx_end = idx
    previous_date = idx_train.date
    while idx_end.date < iter.dates[end]
        idx = find_endpoints(idx_train, ntrain, nvalid, ntest, dates, period)
        idx_train, idx_valid, idx_test, idx_end = idx
        # Xtrain = X[idx_train.index:idx_valid.index - 1, :]
        # Xvalid = X[idx_valid.index:idx_test.index - 1, :]
        # Xtest = X[idx_test.index:idx_end.index, :]
        @show idx_train.date, idx_valid.date, idx_test.date, idx_end.date
        shift!(idx_train, iter.dates, iter.period)
        idx_train.date != previous_date + iter.period && @warn("missing period: $(previous_date) -> $(idx_train.date)")
        previous_date = idx_train.date
    end
end

function expand(X, iter::DateIterator, ntrain, nvalid, ntest)
    size(X, 1) != length(date_iterator.dates) && error("lengths don't match!")
    idx_ref = get_dateindex(iter.dates[1], iter.dates)
    idx_train = copy(idx_ref)
    idx = find_endpoints(idx_ref, ntrain, nvalid, ntest, dates, period)
    idx_ref, idx_valid, idx_test, idx_end = idx
    previous_date = idx_ref.date
    while idx_end.date < iter.dates[end]
        idx = find_endpoints(idx_ref, ntrain, nvalid, ntest, dates, period)
        idx_ref, idx_valid, idx_test, idx_end = idx
        # Xtrain = X[idx_train.index:idx_valid.index - 1, :]
        # Xvalid = X[idx_valid.index:idx_test.index - 1, :]
        # Xtest = X[idx_test.index:idx_end.index, :]
        @show idx_train.date, idx_valid.date, idx_test.date, idx_end.date
        shift!(idx_ref, iter.dates, iter.period)
        idx_ref.date != previous_date + iter.period && @warn("missing period: $(previous_date) -> $(idx_ref.date)")
        previous_date = idx_ref.date
    end
end

function find_endpoints(idx, ntrain, nvalid, ntest, dates, period)
    idx_train = copy(idx)
    idx_valid = copy(shift!(idx, dates, ntrain * period))
    idx_test = copy(shift!(idx, dates, nvalid * period))
    idx_end = copy(shift!(idx, dates, (ntest - 1) * period, firstindex = false))
    return idx_train, idx_valid, idx_test, idx_end
end
