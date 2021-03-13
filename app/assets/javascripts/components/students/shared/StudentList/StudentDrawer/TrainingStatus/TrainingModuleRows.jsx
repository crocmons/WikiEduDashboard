import React from 'react';
import PropTypes from 'prop-types';
import moment from 'moment';

// Helper functions
const orderByDueDate = (a, b) => (moment(a.due_date).isBefore(b.due_date) ? -1 : 1);

// This function compares training's due date with current date
// returns true if the current date has not passed the training's due date
const isTrainingDue = (training) => {
  const currentDate = new Date();
  const trainingDueDate = new Date(Date.parse(training.due_date.replace(/-/g, ' ')));
  return trainingDueDate >= currentDate;
};

export const TrainingModuleRows = ({ trainings }) => {
  trainings.sort(orderByDueDate);
  return trainings.map((trainingModule) => {
    const momentDueDate = moment(trainingModule.due_date);
    const dueDate = momentDueDate.format('MMM Do, YYYY');
    const overdue = trainingModule.overdue || momentDueDate.endOf('day').isBefore(trainingModule.completion_date);
    let moduleStatus;
    if (trainingModule.completion_date) {
      let completionTime = '';
      if (trainingModule.completion_time <= 60 * 60) {
        completionTime = `${I18n.t('training_status.completion_time')}: ${moment.utc(trainingModule.completion_time * 1000).format(`mm [${I18n.t('users.training_module_time.minutes')}] ss [${I18n.t('users.training_module_time.seconds')}]`)}`;
      }
      moduleStatus = (
        <>
          <span className="completed">
            {I18n.t('training_status.completed_at')}: {moment(trainingModule.completion_date).format('YYYY-MM-DD   h:mm A')}
          </span>
          { overdue && <span> ({I18n.t('training_status.late')})</span> }
          <br/>
          <span className="completed">
            {completionTime}
          </span>
        </>
      );
    } else {
      moduleStatus = (
        <>
          <span className="overdue">
            {trainingModule.status}
          </span>
          {overdue && <span> ({I18n.t('training_status.late')})</span>}
        </>
      );
    }


    return (
      <tr className={isTrainingDue(trainingModule) ? 'student-training-module due-training' : 'student-training-module'} key={trainingModule.id}>
        <td>{trainingModule.module_name} <small>Due by { dueDate }</small></td>
        <td>
          { moduleStatus }
        </td>
      </tr>
    );
  });
};

TrainingModuleRows.propTypes = {
  trainings: PropTypes.arrayOf(
    PropTypes.shape({
      completion_date: PropTypes.string,
      id: PropTypes.number.isRequired,
      module_name: PropTypes.string.isRequired,
      status: PropTypes.string
    }).isRequired
  ).isRequired
};

export default TrainingModuleRows;
