use core::poseidon::poseidon_hash_span;

/// Generate a random value within a specified upper_bound.
///
/// Args:
///     salt: u128
///         salt used when generating the seed
///     upper_bound: u128
///         The upper_bound of possible values 
///         i.e output will be from 0 to upper_bound - 1.
///
/// Returns:
///     u128
///         A random value within the specified upper_bound.
///
fn random(salt: u128, upper_bound: u128) -> u128 {
    let seed = make_seed_from_transaction_hash(salt);
    seed.low % upper_bound 
}


fn make_seed_from_transaction_hash(salt: u128) -> u256 {
    return poseidon_hash_span(
        array![
            starknet::get_tx_info().unbox().transaction_hash.into(),
            salt.into() 
        ].span()
    ).into();
}

/// Return a k sized list of population elements chosen with replacement.   
///
/// If the relative weights or cumulative weights are not specified,
/// the selections are made with equal probability.
///
/// Args:
///     population: Span<u128>
///         The population to sample from.
///     weights: Span<u128>
///         The relative weights of each population element.
///     cum_weights: Span<u128>
///         The cumulative weights of each population element.
///         This is to be used in place of weights to speed up calculations
///         if the sum of weights is already available. 
///     k: u128
///         The number of elements to sample.
///
/// Returns:
///     Span<u128>
///         A k sized list of population elements chosen with replacement.
///
/// See Also: https://docs.python.org/3/library/random.html#random.choices
///
fn choices<T, impl TCopy: Copy<T>, impl TDrop: Drop<T>>
    (population: Span<T>, weights: Span<u128>, mut cum_weights: Span<u128>, k: u128) -> Span<T> {

    let mut n = population.len();
    let salt: u128 = starknet::get_block_timestamp().into();  

    if cum_weights.len() == 0 {
        if weights.len() == 0 {
            let mut index = 0;
            let mut result = array![];
            loop {
                if index == k {
                    break;
                }
                result.append(
                    *population.at(random(salt + index.into(), n.into()).try_into().unwrap())
                );
                index += 1;
            };
            return result.span();
        };

        // get cumulative sum of weights
        cum_weights = cum_sum(weights.clone());
        
    } else {
        if weights.len() != 0 {
            assert(false, 'cant specify both weight types');
        };
    };

    if cum_weights.len() != n {
        assert(false, 'weight length mismatch');
    };

    let total = *cum_weights[cum_weights.len() - 1];
    if total == 0 {
        assert(false, 'weights sum is zero');
    };

    let hi = n - 1;
    let mut index = 0;
    let mut result = array![];

    loop {
        if index == k {
            break;
        }
        result.append(
            *population.at(
                bisect_right(
                    cum_weights.clone(), 
                    random(salt + index.into(), total), 
                    0, Option::Some(hi)
                    )
            )
        );
        index += 1;
    };
    return result.span();
}


/// Given a list of values, return a list of the same length, 
/// where each element is the sum of the previous values.
///
/// Args:
///     a: Span<u128>
///         The list of values to sum.
///
/// Returns:
///     Span<u128>
///         The list of sums.
///
/// Example:
///     >>> cum_sum([1, 2, 3, 4, 5])
///     [1, 3, 6, 10, 15]
///
fn cum_sum(a: Span<u128>) -> Span<u128> {
    let mut total = 0;
    let mut result = array![];
    let mut index = 0;
    loop {
        if index == a.len() {
            break;
        }
        total += *a[index];
        result.append(total);
        index += 1;
    };
    return result.span();
}




/// Return the index where to insert item x in list a, assuming a is sorted.
///
/// The return value i is such that all e in a[:i] have e <= x, and all e in
/// a[i:] have e > x.  So if x already appears in the list, i points just
/// beyond the rightmost x already there.
///
/// lo and hi (default len(a)) bound the slice of `a` to be searched.
///
/// Args:
///     a: Span<u128>
///         The list to be searched.
///     x: u128
///         The value to be searched for.
///     lo: u32
///         The lower bound of the slice of a to be searched.
///     hi: Option<u32>
///         The upper bound of the slice of a to be searched.
///
/// Returns:
///     u32
///         The index where to insert item x in list a, assuming a is sorted.
///
/// Example:
///     >>> bisect_right([10, 15, 17 , 20, 21], 16, 0, None)
///     2
///
/// See Also: https://docs.python.org/3/library/bisect.html#bisect.bisect_right
///
fn bisect_right(a: Span<u128>, x: u128, lo: u32, hi: Option<u32>) -> u32 {
    let mut hi 
        = match hi {
            Option::Some(hi) => hi,
            Option::None => a.len().into()
        };

    let mut lo = lo;
    loop {
        if lo >= hi {
            break;
        }
        let mid = (lo + hi) / 2;
        if x < *a.at(mid) {
            hi = mid;
        } else {
            lo = mid + 1;
        };
    };
    return lo;
}
