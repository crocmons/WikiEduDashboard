import { TOGGLE_SCOPING_METHOD, UPDATE_CATEGORIES, UPDATE_CATEGORY_DEPTH, UPDATE_TEMPLATES } from '../constants/scoping_methods';

const initialState = {
  selected: [],
  categories: {
    depth: 1,
    tracked: [],
  },
  templates: {
    include: [],
  }
};

export default function course(state = initialState, action) {
  switch (action.type) {
    case TOGGLE_SCOPING_METHOD: {
      if (state.selected.includes(action.method)) {
        return {
          ...state,
          selected: state.selected.filter(method => method !== action.method).sort(),
        };
      }
      return {
        ...state,
        selected: [...state.selected, action.method].sort(),
      };
    }
    case UPDATE_CATEGORY_DEPTH: {
      return {
        ...state,
        categories: {
          ...state.categories,
          depth: action.depth
        }
      };
    }
    case UPDATE_CATEGORIES: {
      return {
        ...state,
        categories: {
          ...state.categories,
          tracked: action.categories
        }
      };
    }
    case UPDATE_TEMPLATES: {
      return {
        ...state,
        templates: {
          ...state.templates,
          include: action.templates
        }
      };
    }
    default:
      return state;
  }
}
