import { gql } from '@apollo/client';

// Result data used on the admin round view.
// Re-used for mutation responses to update the cache.
export const ROUND_RESULT_FRAGMENT = gql`
  fragment roundResult on Result {
    ranking
    advancing
    attempts {
      result
    }
    best
    average
    person {
      id
      registrantId
      name
    }
    singleRecordTag
    averageRecordTag
  }
`;
